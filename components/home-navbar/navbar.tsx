"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { NavigationMenu, NavigationMenuItem, NavigationMenuLink, NavigationMenuList } from "@/components/ui/navigation-menu";
import Logo from "../shared/logo";
import MobileMenu from "./mobile-menu";

const links = [
  ["Programs", "#learning"],
  ["Learning Method", "#learning"],
  ["Progress", "#learning"],
  ["About", "#learning"],
] as const;

export default function Navbar() {
  const [isScrolled, setIsScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setIsScrolled(window.scrollY > 20);
    window.addEventListener("scroll", onScroll);
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <nav className={"fixed top-0 left-0 right-0 z-50 transition-all duration-300 " + (isScrolled ? "bg-white border-b border-gray-100 shadow-sm" : "bg-transparent")}>
      <div className="max-w-7xl mx-auto px-6">
        <div className="flex items-center justify-between h-20">
          <Logo />
          <NavigationMenu className="hidden md:flex">
            <NavigationMenuList className="gap-8 text-base">
              {links.map(([label, href]) => (
                <NavigationMenuItem key={label}>
                  <NavigationMenuLink asChild>
                    <Link href={href} className={"font-medium transition-colors " + (isScrolled ? "text-gray-900 hover:text-black" : "text-white hover:text-white")}>{label}</Link>
                  </NavigationMenuLink>
                </NavigationMenuItem>
              ))}
            </NavigationMenuList>
          </NavigationMenu>
          <Link href="/auth" className="hidden md:inline-flex px-5 py-2.5 text-lg font-medium text-white bg-blue-800 border border-blue-700 rounded-lg hover:bg-transparent hover:text-blue-700 focus:outline-none focus:ring-4 focus:ring-blue-300 dark:bg-blue-500 dark:border-blue-500">
            Digital Campus
          </Link>
          <MobileMenu />
        </div>
      </div>
    </nav>
  );
}
