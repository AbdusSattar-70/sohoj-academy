import Link from "next/link";
import { TypingText } from "@/components/auth/typing-text";
import Logo from "@/components/shared/logo";
import { ROUTES } from "@/lib/constants";

export default function AuthHomePage() {
  return (
    <div className="flex flex-col md:grid md:grid-cols-[60%_40%] min-h-screen md:h-screen">
      <section className="grow bg-[#00002e] px-6 py-10 md:p-12 flex flex-col">
        <div className="mb-4"><Logo /></div>
        <div className="flex-1 flex items-center justify-center text-center">
          <div>
            <h2 className="text-gray-300 text-base font-semibold">সহজ একাডেমি ডিজিটাল ক্যাম্পাস</h2>
            <h3 className="text-[#d292ff] text-sm sm:text-base font-normal pt-4">I want to<TypingText /></h3>
          </div>
        </div>
      </section>
      <section className="bg-black px-6 py-10 md:p-12 flex flex-col">
        <div className="flex-1 flex items-center justify-center">
          <div className="text-center max-w-sm">
            <h2 className="text-white text-2xl font-bold mb-3">Welcome back</h2>
            <p className="text-gray-400 text-sm mb-6">Sign in to access your Sohoj Academy workspace.</p>
            <Link href={ROUTES.SIGN_IN} className="inline-flex px-6 py-3 text-sm font-medium text-white bg-blue-700 rounded-lg hover:bg-blue-600">Sign In</Link>
          </div>
        </div>
        <div className="text-xs text-gray-500">শিক্ষা হোক সহজ ও আনন্দময়</div>
      </section>
    </div>
  );
}
