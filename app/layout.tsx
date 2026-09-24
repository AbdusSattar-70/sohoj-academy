import type { Metadata } from "next";
import { Montserrat } from "next/font/google";
import { ToastContainer } from "react-toastify";
import "./globals.css";
import "react-toastify/dist/ReactToastify.css";
import { ThemeProvider } from "@/components/theme-provider";
import { TooltipProvider } from "@/components/ui/tooltip";
import { OfflineBanner } from "@/components/shared/OfflineBanner";

const montserrat = Montserrat({ subsets: ["latin"], display: "swap", weight: ["200","300","400","700"], fallback: ["system-ui","sans-serif"] });

export const metadata: Metadata = {
  title: { default: "Sohoj Academy", template: "%s | Sohoj Academy" },
  description: "Sohoj Academy digital campus for students, guardians, teachers and academic operations.",
  icons: { icon: [{ url: "/favicons/favicon.ico" },{ url: "/favicons/favicon-32x32.png", type: "image/png", sizes: "32x32" }], apple: [{ url: "/favicons/apple-touch-icon.png", sizes: "180x180" }] },
  manifest: "/favicons/site.webmanifest",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en" suppressHydrationWarning><body className={`${montserrat.className} antialiased`}>
    <ThemeProvider attribute="class" defaultTheme="dark" enableSystem={false} disableTransitionOnChange>
      <TooltipProvider>{children}</TooltipProvider><OfflineBanner />
    </ThemeProvider>
    <ToastContainer position="bottom-right" autoClose={3000} />
  </body></html>;
}