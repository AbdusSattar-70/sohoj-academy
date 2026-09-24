'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import {
  NavigationMenu,
  NavigationMenuContent,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  NavigationMenuTrigger,
} from '@/components/ui/navigation-menu';
import Logo from '../shared/logo';
import { ROUTES } from '@/lib/constants';
import MobileMenu from './mobile-menu';

export default function Navbar() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileOpen, setIsMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20); // Change background after scrolling 20px
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        isScrolled
          ? 'bg-white border-b border-gray-100 shadow-sm'
          : 'bg-transparent'
      }`}
    >
      <div className="max-w-7xl mx-auto px-6">
        <div className="flex items-center justify-between h-20">
          <Logo />

          {/* Desktop Navigation */}
          <NavigationMenu className="hidden md:flex">
            <NavigationMenuList className="gap-8 text-base">
              <NavigationMenuItem>
                <NavigationMenuTrigger 
                  className={`font-medium transition-colors px-0 py-0 hover:bg-transparent data-[state=open]:bg-transparent ${
                    isScrolled ? 'text-gray-900' : 'text-white hover:text-white'
                  }`}
                >
                  Services
                </NavigationMenuTrigger>
                <NavigationMenuContent className="w-150 p-8">
                  {/* Add your dropdown content here */}
                </NavigationMenuContent>
              </NavigationMenuItem>

              <NavigationMenuItem>
                <NavigationMenuTrigger 
                  className={`font-medium transition-colors px-0 py-0 hover:bg-transparent data-[state=open]:bg-transparent ${
                    isScrolled ? 'text-gray-900' : 'text-white hover:text-white'
                  }`}
                >
                  Industries
                </NavigationMenuTrigger>
                <NavigationMenuContent>
                  {/* Industries dropdown */}
                </NavigationMenuContent>
              </NavigationMenuItem>

              <NavigationMenuItem>
                <Link href="/case-studies" legacyBehavior passHref>
                  <NavigationMenuLink 
                    className={`font-medium transition-colors ${
                      isScrolled ? 'text-gray-900 hover:text-black' : 'text-white hover:text-white'
                    }`}
                  >
                    Case studies
                  </NavigationMenuLink>
                </Link>
              </NavigationMenuItem>

              <NavigationMenuItem>
                <NavigationMenuTrigger 
                  className={`font-medium transition-colors px-0 py-0 hover:bg-transparent data-[state=open]:bg-transparent ${
                    isScrolled ? 'text-gray-900' : 'text-white hover:text-white'
                  }`}
                >
                  Insights
                </NavigationMenuTrigger>
                <NavigationMenuContent>
                  {/* Insights dropdown */}
                </NavigationMenuContent>
              </NavigationMenuItem>

              <NavigationMenuItem>
                <NavigationMenuTrigger 
                  className={`font-medium transition-colors px-0 py-0 hover:bg-transparent data-[state=open]:bg-transparent ${
                    isScrolled ? 'text-gray-900' : 'text-white hover:text-white'
                  }`}
                >
                  Company
                </NavigationMenuTrigger>
                <NavigationMenuContent>
                  {/* Company dropdown */}
                </NavigationMenuContent>
              </NavigationMenuItem>
            </NavigationMenuList>
          </NavigationMenu>

          <Link
            href={ROUTES.AUTH}
            className="px-5 py-2.5 text-lg font-medium text-white bg-blue-800 border border-blue-700 rounded-lg hover:bg-transparent hover:text-blue-700 focus:outline-none focus:ring-4 focus:ring-blue-300 dark:bg-blue-500 dark:text-white dark:border-blue-500 dark:hover:bg-transparent dark:hover:text-blue-500 dark:focus:ring-blue-800 text-center"
          >
            Start Your Free Trial
          </Link>

          {/* Mobile Menu Button */}
          {/* <button
            className={`md:hidden transition-colors ${
              isScrolled ? 'text-gray-900' : 'text-white'
            }`}
            onClick={() => setIsMobileOpen(!isMobileOpen)}
            aria-label="Toggle menu"
          >
            {isMobileOpen ? <X size={28} /> : <Menu size={28} />}
          </button> */}
           <MobileMenu />
        </div>
      </div>

      {/* Mobile Menu */}
      {isMobileOpen && (
        <div className="md:hidden bg-blue-500 border-t">
          <div className="px-6 py-8 flex flex-col gap-6 text-lg font-medium">
            <Link href="#" className="py-2">Services</Link>
            <Link href="#" className="py-2">Industries</Link>
            <Link href="/case-studies" className="py-2">Case studies</Link>
            <Link href="#" className="py-2">Insights</Link>
            <Link href="#" className="py-2">Company</Link>

          <Link
            href={ROUTES.AUTH}
            className="px-5 py-2.5 text-lg font-medium text-white bg-blue-800 border border-blue-700 rounded-lg hover:bg-transparent hover:text-blue-700 focus:outline-none focus:ring-4 focus:ring-blue-300 dark:bg-blue-500 dark:text-white dark:border-blue-500 dark:hover:bg-transparent dark:hover:text-blue-500 dark:focus:ring-blue-800 text-center"
          >
            Start Your Free Trial
          </Link>
          </div>
        </div>
      )}
    </nav>
  );
}