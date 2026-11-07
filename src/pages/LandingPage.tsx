import { HeroCard } from "../components/landing/HeroCard";
import { HeroSection } from "../components/landing/HeroSection";
import { SiteFooter } from "../components/SiteFooter";
import { SiteHeader } from "../components/SiteHeader";

export default function LandingPage() {
  return (
    <main className="page landing">
      <SiteHeader
        suffix="Ketua Angkatan"
        nav={[
          { label: "Antrean saat ini", to: "/antrian" },
          { label: "Hasil pemilihan", to: "/results" },
          { label: "Admin", to: "/admin" },
        ]}
      />
      <section className="hero">
        <HeroSection />
        <HeroCard />
      </section>
      <SiteFooter>Pemilihan yang tertib, aman, dan rahasia.</SiteFooter>
    </main>
  );
}
