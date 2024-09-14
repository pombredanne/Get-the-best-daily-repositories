// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Copyright (c) 2023 Tesla Inc. All rights reserved.
 *
 * TTP (TTPoE) A reference implementation of Tesla Transport Protocol (TTP) that runs directly
 *             over Ethernet Layer-2 Network. This is implemented as a Loadable Kernel Module
 *             that establishes a TTP-peer connection with another instance of the same module
 *             running on another Linux machine on the same Layer-2 network. Since TTP runs
 *             over Ethernet, it is often referred to as TTP Over Ethernet (TTPoE).
 *
 *             The Protocol is specified to work at high bandwidths over 100Gbps and is mainly
 *             designed to be implemented in Hardware as part of Tesla's DOJO project.
 *
 *             This public release of the TTP software implementation is aligned with the patent
 *             disclosure and public release of the main TTP Protocol specification. Users of
 *             this software module must take into consideration those disclosures in addition
 *             to the license agreement mentioned here.
 *
 * Authors:    Diwakar Tundlam <dntundlam@tesla.com>
 *             Bill Chang <wichang@tesla.com>
 *             Spencer Sharkey <spsharkey@tesla.com>
 *
 * TTP-Spec:   Eric Quinnell <equinnell@tesla.com>
 *             Doug Williams <dougwilliams@tesla.com>
 *             Christopher Hsiong <chsiong@tesla.com>
 *
 * Version:    08/26/2022 wichang@tesla.com, "Initial version"
 *             02/09/2023 spsharkey@tesla.com, "add ttpoe header parser + test"
 *             05/11/2023 dntundlam@tesla.com, "ttpoe layers - network, transport, and payload"
 *             07/11/2023 dntundlam@tesla.com, "functional state-machine, added tests"
 *             09/29/2023 dntundlam@tesla.com, "final touches"
 *             09/10/2024 dntundlam@tesla.com, "sync with TTP_Opcodes.pdf [rev 1.5]"
 *
 * This software is licensed under the terms of the GNU General Public License version 2 as published
 * by the Free Software Foundation, and may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * Without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 */

#define TTP_NOC_BUF_SIZE  (1024) /* Size of full NOC buffer, including NOC Header and NOC Data */
#define TTP_NOC_DAT_SIZE  (TTP_NOC_BUF_SIZE - sizeof (struct ttp_ttpoe_noc_hdr))
#define TTP_NOC_NUM_64B   (TTP_NOC_DAT_SIZE / sizeof (u64))


enum ttp_frame_direction {
    TTP_RX,                     /* 0 */
    TTP_TX,                     /* 1 */
};

/* Transport Header (TTP) that follows TSH
 *
 *  15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |         opcode [7:0]          |             vc [7:0]          |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |             tx [7:0]          |             rx [7:0]          |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |                          epoch [15:0]                         |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |         congestion [7:0]      |      reserved-byte [7:0]      |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |      reserved-byte [7:0]      |          extension [7:0]      |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |                       tx-sequence [31:0]                      |
 * |                                                               |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |                       rx-sequence [31:0]                      |
 * |                                                               |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 */
struct ttp_transport_hdr {
    u8  conn_opcode;
    u8  conn_vc;

    u8  conn_tx;
    u8  conn_rx;
    u16 conn_epoch;

    u8  conn_congestion;
    u16 conn_reserved1;
    u8  conn_extension;

    u32 conn_tx_seq;
    u32 conn_rx_seq;
} __attribute__((packed));


#define TTP_HEADERS_LEN  (sizeof (struct ttp_tsla_shim_hdr) + sizeof (struct ttp_transport_hdr))
#define TTP_TTH_HDR_LEN  (sizeof (struct ttp_tsla_type_hdr) + TTP_HEADERS_LEN)


enum ttp_extn_types_enum {
    TTP_ET__BASE             = 0x00, /* implicit types */
    TTP_ET__PROTOCOL         = 0x00, /* implicit types */
    TTP_ET__DATA_VC          = 0x00, /* implicit types */
    TTP_ET__REQUEST_VC       = 0x00, /* implicit types */

    TTP_ET__EXPLICIT_ADDR    = 0x00,

    TTP_ET__FEATURE_NEG_0    = 0x10, /* 0x1x - 0x1f */
    TTP_ET__FEATURE_NEG_N    = 0x1f,

    TTP_ET__SEL_ACK          = 0x20,

    TTP_ET__PAYLOAD_MOD      = 0xd0,
    TTP_ET__PAYLOAD_OFFSET   = 0xe0,

    TTP_ET__PAYLOAD_HEADER_0 = 0xe1, /* 0xe1 - 0xef */
    TTP_ET__PAYLOAD_HEADER_N = 0xef,

    TTP_ET__FCS_0            = 0xf0, /* 0xf0 - 0xfe */
    TTP_ET__FCS_N            = 0xfe,

    TTP_ET__PADDING          = 0xff,
};


struct ttp_extn_types {
    u8 type;
    union /* anonymous */ {
        u8 fill_base[7];
        u8 extn_hdr1[7];
    };
} __attribute__((packed));


/* Extension Header (NOC) that follows TTP (transport header)
 *
 *  15  14  13  12  11  10   9   8   7   6   5   4   3   2   1   0
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |           type [7:0]          |                               |
 * +---+---+---+---+---+---+---+---+                               |
 * |                                                               |
 * |                    extension header-1 [55:0]                  |
 * |                                                               |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 * |                                                               |
 * |                                                               |
 * |                    extension header-2 [63:0]                  |
 * |                                                               |
 * |                                                               |
 * +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
 */
struct ttp_ttpoe_noc_hdr {
    union /* anonymous */ {
        struct ttp_extn_types xhdr1_fmt;
        u64                   xhdr1_u64;
    };
    u64                       xhdr2_u64;
} __attribute__((packed));


struct ttp_ttpoe_noc_dat {
    union {
        u64 noc_data_u64[TTP_NOC_NUM_64B];
        u8  noc_data_raw[TTP_NOC_DAT_SIZE];
    };
} __attribute__((packed));


struct ttp_frame_hdr {
    struct ethhdr            *eth;
    struct ttp_tsla_type_hdr *tth;
    struct ttp_tsla_shim_hdr *tsh;
    struct ttp_transport_hdr *ttp;
    struct ttp_ttpoe_noc_hdr *noc;
    struct ttp_ttpoe_noc_dat *dat;
} __attribute__((packed));


struct ttp_pkt_info {
    u16 noc_len;                /* max value: TTP_NOC_BUF_SIZE */

    u32 rxi_seq;
    u32 txi_seq;

    u16 tth_off;
    u16 tsh_off;
    u16 ttp_off;
    u16 noc_off;
    u16 dat_off;

    u8 *skb_dat;                /* saved skb->data */
    u16 skb_len;                /* saved skb->len */
} __attribute__((packed));


struct ttp_fsm_event;
enum   ttp_opcodes_enum;

#ifdef __KERNEL__
extern bool ttp_random_flip (int pct);

extern void ttp_skb_drop (struct sk_buff *skb);
extern void ttp_skb_xmit (struct sk_buff *skb);

extern void ttp_tsk_bind (struct ttp_fsm_event *ev, const struct ttp_fsm_event *qev);

extern u8  *ttp_skb_aloc (struct sk_buff **skbp, const int nl);
extern u8  *ttp_skb_prep (struct sk_buff **skbp, struct ttp_fsm_event *qev,
                          enum ttp_opcodes_enum op);

extern void ttp_skb_pars (const struct sk_buff *skb, struct ttp_frame_hdr *fh,
                          struct ttp_pkt_info *pf);
extern bool ttp_skb_pars_get_gw_flag (const struct sk_buff *skb);

extern int  ttp_skb_chek (const struct sk_buff *skb);
extern int  ttp_skb_enqu (struct sk_buff *skb);

extern int  ttp_skb_dequ (void);

extern int  __init ttpoe_proc_init (void);
extern void __exit ttpoe_proc_exit (void);
#endif
