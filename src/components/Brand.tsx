import { Link } from "react-router";
const LOGOS = [
  { src: "/logo-unej.png", alt: "Logo Universitas Jember" },
  { src: "/logo-elektro.png", alt: "Logo Teknik Elektro" },
];

export function Brand({ suffix = "Teknik Elektro" }: { suffix?: string }) {
  return (
    <Link to="/" className="brand">
      <span className="brand-logos">
        {LOGOS.map((logo) => (
          <img
            key={logo.src}
            className="brand-logo"
            src={logo.src}
            alt={logo.alt}
            onError={(event) => {
              
              event.currentTarget.style.display = "none";
            }}
          />
        ))}
      </span>
      <span className="brand-text">
        E-Voting <span>{suffix}</span>
      </span>
    </Link>
  );
}
