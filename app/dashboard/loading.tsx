export default function Loading() {
  return (
    <div className="flex items-center justify-center h-screen bg-background text-white">
      <div className="relative w-60 h-60">
        {/* Spinning Outer Border */}
        <div
          className="absolute inset-0 rounded-full border-30 border-t-blue-500 border-r-violet-500 border-b-green-500 border-l-yellow-400 animate-spin
  bg-white/5 backdrop-blur-sm shadow-md shadow-black/10"
        />

        {/* Centered Logo */}
        <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
          <div className="flex items-center space-x-2">
            <svg
              className="w-12 h-12 text-blue-500"
              viewBox="0 0 84 96"
              xmlns="http://www.w3.org/2000/svg"
            >
              <title>Logo</title>

              {/* Animate polygon stroke */}
              <polygon
                points="39 0 0 22 0 67 39 90 78 68 78 23"
                fill="none"
                stroke="currentColor"
                strokeWidth="5"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="animate-draw-polygon"
              />

              <text
                x="39"
                y="60"
                textAnchor="middle"
                fontSize="50"
                fill="currentColor"
                fontFamily="monospace"
              >
                F
              </text>
            </svg>

            <span className="text-xl font-semibold bg-gradient-to-r from-blue-500 to-violet-600 bg-clip-text text-transparent hidden sm:inline">
              F-Ledger
            </span>
          </div>

          <p className="text-xs mt-1 text-gray-300 italic">
            Dashboard is loading...
          </p>
        </div>
      </div>
    </div>
  );
}
