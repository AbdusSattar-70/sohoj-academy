"use client";
import Lottie from "lottie-react";
import money from "@/public/animation/money.json";
export function DollarAnimation() {
  const style = {
    height: 60,
  };
  return <Lottie animationData={money} loop={true} style={style} />;
}
