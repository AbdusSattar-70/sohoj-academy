import { HeroVideo } from "@/components/shared/hero-video";
import Logo from "@/components/shared/logo";
import { TypingText } from "@/components/auth/typing-text";
import CardSection from "@/components/card-section";
import Navbar from "@/components/home-navbar/navbar";
import MobileMenu from "@/components/home-navbar/mobile-menu";

export default function HomePage() {
  return (
    <div>
      <Navbar/>
    <div className="relative h-screen w-full bg-background text-foreground">
      <HeroVideo />
      <div className="absolute top-50 inset-x-0 z-30 text-center px-6 md:px-10 text-white max-w-3xl mx-auto transition-opacity duration-500">
               <div className="flex-1 flex items-center justify-center text-center">
                 <div>
                   <h2 className="text-gray-300 text-base font-semibold flex items-center justify-center">
                     What will you accomplish with{" "}
                     <Logo/>
                     ?
                   </h2>
                   <h3 className="text-[#d292ff] text-sm sm:text-base font-normal pt-4">
                     I want to
                     <TypingText />
                   </h3>
                 </div>
               </div>
      </div>
    </div>
      <CardSection />
                 <MobileMenu />
      
    </div>
  );
}
