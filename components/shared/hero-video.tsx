export const HeroVideo = () => {
  return (
    <>
      <video
        autoPlay
        loop
        muted
        preload="auto"
        playsInline
        poster="/image/hero-section.webp"
        className="absolute inset-0 h-full w-full object-cover z-0"
      >
        <source src="/videos/hero-section.mp4" type="video/mp4" />
      </video>

      <div className="absolute inset-0 bg-black/40 z-10" />
    </>
  );
};
