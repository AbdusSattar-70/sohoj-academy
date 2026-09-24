import { cards } from "@/app/data/cards";
import { FeatureCard } from "./feature-card";

export default function CardSection() {
  return (
    <section className="container py-24">
<div className="mb-20">
  <p className="mb-4 text-sm font-medium text-primary">
    PLATFORM CAPABILITIES
  </p>

  <h2 className="max-w-4xl text-2xl font-bold tracking-tight md:text-7xl">
    Financial management built on
    <span className="text-primary">
      {" "}transactional truth
    </span>
  </h2>
</div>
        {/* Row 1 */}
        <div className="grid grid-cols-12">
          <div className="col-span-3 h-80">
            <FeatureCard {...cards[0]} />
          </div>

          <div className="col-span-3 h-80">
            <FeatureCard {...cards[1]} />
          </div>

          <div className="col-span-6 h-80">
            <FeatureCard {...cards[2]} />
          </div>
        </div>

        {/* Row 2 */}
        <div className="grid grid-cols-12">
          {cards.slice(3, 7).map((card) => (
            <div
              key={card.title}
              className="col-span-3 h-65"
            >
              <FeatureCard {...card} />
            </div>
          ))}
        </div>

        {/* Row 3 */}
        <div className="grid grid-cols-12">
          <div className="col-span-6 h-80">
            <FeatureCard {...cards[7]} />
          </div>

          <div className="col-span-3 h-80">
            <FeatureCard {...cards[8]} />
          </div>

          <div className="col-span-3 h-80">
            <FeatureCard {...cards[9]} />
          </div>
        </div>

        {/* Row 4 */}
        <div className="grid grid-cols-12">
          <div className="col-span-3 h-80">
            <FeatureCard {...cards[10]} />
          </div>

          <div className="col-span-3 h-80">
            <FeatureCard {...cards[11]} />
          </div>

          <div className="col-span-6 h-80">
            <FeatureCard {...cards[12]} />
          </div>
        </div>
    </section>
  );
}