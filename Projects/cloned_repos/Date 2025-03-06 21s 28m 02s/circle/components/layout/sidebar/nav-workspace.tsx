'use client';

import { ContactRound, LayoutList, MoreHorizontal, UserRound, type LucideIcon } from 'lucide-react';

import {
   DropdownMenu,
   DropdownMenuContent,
   DropdownMenuItem,
   DropdownMenuSeparator,
   DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
   SidebarGroup,
   SidebarGroupLabel,
   SidebarMenu,
   SidebarMenuButton,
   SidebarMenuItem,
} from '@/components/ui/sidebar';
import { RemixiconComponentType } from '@remixicon/react';
import Link from 'next/link';

export function NavWorkspace({
   workspace,
}: {
   workspace: {
      name: string;
      url: string;
      icon: LucideIcon | RemixiconComponentType;
   }[];
}) {
   return (
      <SidebarGroup className="group-data-[collapsible=icon]:hidden">
         <SidebarGroupLabel>Workspace</SidebarGroupLabel>
         <SidebarMenu>
            {workspace.map((item) => (
               <SidebarMenuItem key={item.name}>
                  <SidebarMenuButton asChild>
                     <Link href={item.url}>
                        <item.icon />
                        <span>{item.name}</span>
                     </Link>
                  </SidebarMenuButton>
               </SidebarMenuItem>
            ))}
            <SidebarMenuItem>
               <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                     <SidebarMenuButton asChild>
                        <span>
                           <MoreHorizontal />
                           <span>More</span>
                        </span>
                     </SidebarMenuButton>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent className="w-48 rounded-lg" side="bottom" align="start">
                     <DropdownMenuItem>
                        <ContactRound className="text-muted-foreground" />
                        <span>Teams</span>
                     </DropdownMenuItem>
                     <DropdownMenuItem>
                        <UserRound className="text-muted-foreground" />
                        <span>Members</span>
                     </DropdownMenuItem>
                     <DropdownMenuSeparator />
                     <DropdownMenuItem>
                        <LayoutList className="text-muted-foreground" />
                        <span>Customize sidebar</span>
                     </DropdownMenuItem>
                  </DropdownMenuContent>
               </DropdownMenu>
            </SidebarMenuItem>
         </SidebarMenu>
      </SidebarGroup>
   );
}
