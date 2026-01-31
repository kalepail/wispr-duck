import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'

const GITHUB_URL = 'https://github.com/kalepail/wispr-duck'
const TWITTER_URL = 'https://x.com/kalepail'
const GITHUB_PROFILE_URL = 'https://github.com/kalepail'

function DuckFootIcon({ className, decorative = false }) {
  return (
    <svg
      className={className}
      width="200"
      height="200"
      viewBox="0 0 200 200"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden={decorative ? 'true' : undefined}
      role={decorative ? undefined : 'img'}
    >
      {!decorative && <title>WisprDuck logo</title>}
      <path d="M 100,195 C 85,168 28,95 8,30 C 2,16 8,12 16,20 C 28,35 45,52 56,64 C 64,72 74,72 84,60 C 90,46 95,22 100,4 C 105,22 110,46 116,60 C 126,72 136,72 144,64 C 155,52 172,35 184,20 C 192,12 198,16 192,30 C 172,95 115,168 100,195 Z" fill="currentColor"/>
      <path d="M 100,158 C 90,125 78,92 64,68" fill="none" stroke="white" strokeWidth="5" strokeLinecap="round" opacity="0.3"/>
      <path d="M 100,158 C 110,125 122,92 136,68" fill="none" stroke="white" strokeWidth="5" strokeLinecap="round" opacity="0.3"/>
    </svg>
  )
}

function GitHubIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
    </svg>
  )
}

function XIcon({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
    </svg>
  )
}

function PixelGrass() {
  return (
    <div className="absolute bottom-0 left-0 right-0 h-8 overflow-hidden pointer-events-none" aria-hidden="true">
      <svg width="100%" height="32" viewBox="0 0 320 32" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
        <rect y="16" width="320" height="16" fill="#1e4620"/>
        <rect y="24" width="320" height="8" fill="#132a14"/>
        {Array.from({ length: 40 }, (_, i) => (
          <rect key={i} x={i * 8} y={12 + (i % 3) * 4} width="4" height={8 - (i % 3) * 2} fill="#2d5a30"/>
        ))}
      </svg>
    </div>
  )
}

function PixelStars() {
  const stars = [
    { x: '10%', y: '15%', size: 2 }, { x: '25%', y: '8%', size: 3 },
    { x: '40%', y: '20%', size: 2 }, { x: '55%', y: '5%', size: 2 },
    { x: '70%', y: '18%', size: 3 }, { x: '85%', y: '10%', size: 2 },
    { x: '15%', y: '25%', size: 2 }, { x: '65%', y: '12%', size: 2 },
    { x: '90%', y: '22%', size: 3 }, { x: '35%', y: '3%', size: 2 },
    { x: '78%', y: '28%', size: 2 }, { x: '48%', y: '15%', size: 3 },
  ]

  return (
    <div className="absolute inset-0 pointer-events-none" aria-hidden="true">
      {stars.map((star, i) => (
        <div
          key={i}
          className="absolute bg-pixel-yellow rounded-none animate-pulse"
          style={{
            left: star.x,
            top: star.y,
            width: star.size,
            height: star.size,
            animationDelay: `${i * 0.3}s`,
            opacity: 0.6 + (i % 3) * 0.15,
          }}
        />
      ))}
    </div>
  )
}

function CrosshairDecor() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none opacity-[0.04]" aria-hidden="true">
      <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="crosshair" x="0" y="0" width="80" height="80" patternUnits="userSpaceOnUse">
            <circle cx="40" cy="40" r="12" fill="none" stroke="#4ade80" strokeWidth="1"/>
            <line x1="40" y1="24" x2="40" y2="32" stroke="#4ade80" strokeWidth="1"/>
            <line x1="40" y1="48" x2="40" y2="56" stroke="#4ade80" strokeWidth="1"/>
            <line x1="24" y1="40" x2="32" y2="40" stroke="#4ade80" strokeWidth="1"/>
            <line x1="48" y1="40" x2="56" y2="40" stroke="#4ade80" strokeWidth="1"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#crosshair)" />
      </svg>
    </div>
  )
}

const features = [
  {
    icon: '\u{1F3AF}',
    title: 'Per-App Triggers',
    description: 'Choose which apps trigger ducking. Defaults to Wispr Flow \u2014 add any mic-using app you want.',
    color: 'text-pixel-green',
  },
  {
    icon: '\u{1F3AE}',
    title: 'Smooth Volume Fading',
    description: 'Linear 1-second volume transitions. No harsh jumps \u2014 just buttery-smooth audio ducking.',
    color: 'text-pixel-orange',
  },
  {
    icon: '\u{1F4A5}',
    title: 'Selective Ducking',
    description: 'Duck all audio or pick specific apps. Spotify, Chrome, Arc, Safari \u2014 20+ apps supported out of the box.',
    color: 'text-pixel-blue',
  },
  {
    icon: '\u{1F6E1}\uFE0F',
    title: 'Crash-Safe',
    description: 'Uses Core Audio\u2019s mutedWhenTapped \u2014 audio auto-restores even if WisprDuck quits unexpectedly.',
    color: 'text-pixel-yellow',
  },
  {
    icon: '\u26A1',
    title: 'Lightweight',
    description: 'Event-driven Core Audio listeners \u2014 no polling. Minimal CPU usage sitting in your menu bar.',
    color: 'text-pixel-teal',
  },
  {
    icon: '\u{1F4E6}',
    title: 'Open Source',
    description: 'Apache 2.0 licensed. Inspect, modify, and contribute on GitHub.',
    color: 'text-pixel-green',
  },
]

function SkipLink() {
  return (
    <a href="#main" className="skip-link">
      Skip to main content
    </a>
  )
}

function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-40 bg-hunter-dark/90 backdrop-blur-sm border-b-2 border-hunter-border" aria-label="Main navigation">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2.5 min-w-0 group py-2">
          <DuckFootIcon className="w-7 h-7 text-pixel-green shrink-0 transition-transform group-hover:scale-110" decorative />
          <span className="font-pixel text-sm text-pixel-green tracking-wide">WISPRDUCK</span>
        </a>
        <div className="flex items-center gap-5 sm:gap-6">
          <a href="#features" className="font-pixel text-[10px] text-pixel-green/50 hover:text-pixel-green transition-colors hidden sm:block tracking-wide py-2">FEATURES</a>
          <a href="#how-it-works" className="font-pixel text-[10px] text-pixel-green/50 hover:text-pixel-green transition-colors hidden sm:block tracking-wide py-2">HOW</a>
          <a href="#download" className="font-pixel text-[10px] text-pixel-green/50 hover:text-pixel-green transition-colors hidden sm:block tracking-wide py-2">DOWNLOAD</a>
          <Separator orientation="vertical" className="h-5 bg-hunter-border hidden sm:block" />
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="text-pixel-green/50 hover:text-pixel-green transition-colors p-2" aria-label="WisprDuck on GitHub">
            <GitHubIcon className="w-6 h-6" />
          </a>
          <a href={TWITTER_URL} target="_blank" rel="noopener noreferrer" className="text-pixel-green/50 hover:text-pixel-green transition-colors p-2" aria-label="@kalepail on X (Twitter)">
            <XIcon className="w-6 h-6" />
          </a>
        </div>
      </div>
    </nav>
  )
}

function Hero() {
  return (
    <section className="relative pt-24 sm:pt-32 pb-24 sm:pb-32 px-6 overflow-hidden bg-gradient-to-b from-sky-top via-hunter-dark to-hunter-bg" aria-labelledby="hero-heading">
      <PixelStars />
      <CrosshairDecor />

      {/* Pixel glow orbs */}
      <div className="absolute top-1/3 left-1/4 w-48 sm:w-72 h-48 sm:h-72 bg-pixel-green/5 rounded-full blur-3xl" aria-hidden="true" />
      <div className="absolute bottom-1/4 right-1/5 w-48 sm:w-72 h-48 sm:h-72 bg-pixel-orange/5 rounded-full blur-3xl" aria-hidden="true" />

      <div className="relative z-10 text-center max-w-4xl mx-auto">
        <Badge variant="outline" className="mb-8 border-pixel-green/30 bg-hunter-card/50 text-pixel-green font-pixel text-[10px] tracking-wider px-5 py-2.5">
          <span className="w-2 h-2 bg-pixel-green rounded-none animate-blink inline-block mr-2" aria-hidden="true" />
          FREE &amp; OPEN SOURCE
        </Badge>

        <h1 id="hero-heading" className="font-pixel text-3xl sm:text-5xl lg:text-6xl tracking-tight mb-6 text-glow-green text-pixel-green leading-relaxed">
          WISPRDUCK
        </h1>

        <p className="font-pixel text-sm sm:text-base text-pixel-orange mb-4 text-glow-orange tracking-wide">
          {'Shhh\u2026 Ducking volume.'}
        </p>

        <p className="text-base sm:text-lg text-[#a3b89a] max-w-2xl mx-auto mb-10 leading-relaxed">
          A lightweight macOS menu bar app that{' '}
          <strong className="text-pixel-green font-semibold">automatically reduces background audio</strong>{' '}
          when your microphone is active. Built for{' '}
          <strong className="text-pixel-orange font-semibold">Wispr Flow</strong>
          {' '}and perfect for video&nbsp;calls, voice&#8209;to&#8209;text, and screen&nbsp;recordings.
        </p>

        <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12 sm:mb-16">
          <Button
            asChild
            size="lg"
            className="font-pixel text-sm tracking-wider bg-pixel-green text-hunter-dark hover:bg-pixel-green/90 border-2 border-pixel-green-dim px-10 py-7 rounded-none pixel-border shadow-[0_0_20px_rgba(74,222,128,0.3)] hover:shadow-[0_0_30px_rgba(74,222,128,0.5)] transition-shadow"
          >
            <a href={`${GITHUB_URL}/releases`} target="_blank" rel="noopener noreferrer">
              <GitHubIcon className="w-5 h-5" />
              PRESS START
            </a>
          </Button>
          <Button
            asChild
            variant="outline"
            size="lg"
            className="font-pixel text-sm tracking-wider border-2 border-hunter-border text-pixel-green/70 hover:text-pixel-green hover:border-pixel-green/30 bg-hunter-card/30 px-10 py-7 rounded-none"
          >
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
              VIEW SOURCE
            </a>
          </Button>
        </div>

        {/* Main banner showcase */}
        <div className="relative max-w-3xl mx-auto">
          <div className="absolute -inset-1 bg-gradient-to-b from-pixel-green/20 via-pixel-orange/10 to-transparent rounded-sm blur-sm" aria-hidden="true" />
          <div className="relative border-2 border-hunter-border overflow-hidden rounded-sm pixel-border bg-hunter-dark">
            <img
              src="/banner-fun-3.png"
              alt="Four retro pixel art panels showing WisprDuck installation screens with duck hunter game aesthetics, featuring pixel ducks and CRT monitors"
              className="w-full h-auto block"
              loading="eager"
              fetchpriority="high"
              decoding="async"
            />
          </div>
        </div>
      </div>

      <PixelGrass />
    </section>
  )
}

function HowItWorks() {
  const steps = [
    { num: '01', label: 'DETECT', desc: 'Core Audio listener fires when a trigger app activates the mic. Choose which apps or allow all.', color: 'text-pixel-green', border: 'border-pixel-green/30', glow: 'shadow-[0_0_10px_rgba(74,222,128,0.15)]' },
    { num: '02', label: 'TAP', desc: 'Process taps are created for target apps, intercepting their audio output.', color: 'text-pixel-orange', border: 'border-pixel-orange/30', glow: 'shadow-[0_0_10px_rgba(251,146,60,0.15)]' },
    { num: '03', label: 'SCALE', desc: 'Intercepted audio is scaled by your chosen duck level and played through.', color: 'text-pixel-blue', border: 'border-pixel-blue/30', glow: 'shadow-[0_0_10px_rgba(56,189,248,0.15)]' },
    { num: '04', label: 'RESTORE', desc: `When the mic goes idle, volume ramps back up smoothly over ~1\u00A0second.`, color: 'text-pixel-yellow', border: 'border-pixel-yellow/30', glow: 'shadow-[0_0_10px_rgba(250,204,21,0.15)]' },
  ]

  return (
    <section id="how-it-works" className="relative py-20 sm:py-28 px-6 scroll-mt-20 bg-hunter-bg" aria-labelledby="how-heading">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-12 sm:mb-16">
          <h2 id="how-heading" className="font-pixel text-lg sm:text-2xl text-pixel-green text-glow-green mb-4">HOW IT WORKS</h2>
          <p className="text-[#6b8f6e] max-w-xl mx-auto">Four simple steps. Zero configuration. Just install and go.</p>
        </div>

        <ol className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 list-none p-0 m-0">
          {steps.map(step => (
            <li key={step.num}>
              <Card className={`bg-hunter-card/60 border-2 ${step.border} rounded-none pixel-border ${step.glow} hover:scale-[1.02] transition-transform h-full`}>
                <CardContent className="pt-6">
                  <span className={`font-pixel text-3xl ${step.color} opacity-30 block`} aria-hidden="true">{step.num}</span>
                  <h3 className={`font-pixel text-xs mt-3 ${step.color} tracking-wider`}>{step.label}</h3>
                  <p className="text-[#6b8f6e] mt-3 text-sm leading-relaxed">{step.desc}</p>
                </CardContent>
              </Card>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}

function Features() {
  return (
    <section id="features" className="relative py-20 sm:py-28 px-6 scroll-mt-20 bg-hunter-dark" aria-labelledby="features-heading">
      <CrosshairDecor />
      <div className="relative z-10 max-w-6xl mx-auto">
        <div className="text-center mb-12 sm:mb-16">
          <h2 id="features-heading" className="font-pixel text-lg sm:text-2xl text-pixel-orange text-glow-orange mb-4">POWER-UPS</h2>
          <p className="text-[#6b8f6e] max-w-xl mx-auto">Built with Core Audio process taps for rock-solid, low-latency audio ducking.</p>
        </div>

        <ul className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 list-none p-0 m-0">
          {features.map(feature => (
            <li key={feature.title}>
              <Card className="bg-hunter-card/40 border-2 border-hunter-border rounded-none pixel-border hover:border-pixel-green/20 hover:shadow-[0_0_15px_rgba(74,222,128,0.1)] transition-all h-full">
                <CardContent className="pt-6">
                  <span className="text-2xl mb-2 block" role="img" aria-label={feature.title}>{feature.icon}</span>
                  <h3 className={`font-pixel text-xs tracking-wider mb-3 ${feature.color}`}>{feature.title.toUpperCase()}</h3>
                  <p className="text-[#6b8f6e] text-sm leading-relaxed">{feature.description}</p>
                </CardContent>
              </Card>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

function ScoreBoard() {
  const stats = [
    { label: 'CPU USAGE', value: '~0%', note: 'Event-driven, no polling' },
    { label: 'FADE TIME', value: '~1s', note: 'Smooth linear ramp' },
    { label: 'PRICE', value: 'FREE', note: 'Apache 2.0 license' },
    { label: 'REQUIRES', value: '14.2+', note: 'macOS Sonoma' },
  ]

  return (
    <section className="py-16 sm:py-20 px-6 bg-hunter-bg border-y-2 border-hunter-border">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-10">
          <h2 className="font-pixel text-base sm:text-lg text-pixel-yellow tracking-wider">HIGH SCORES</h2>
        </div>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {stats.map(stat => (
            <div key={stat.label} className="text-center py-4">
              <div className="font-pixel text-2xl sm:text-3xl text-pixel-green text-glow-green mb-2">{stat.value}</div>
              <div className="font-pixel text-[10px] sm:text-xs text-pixel-orange/70 tracking-wider mb-1">{stat.label}</div>
              <div className="text-xs text-[#6b8f6e]">{stat.note}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

function Download() {
  return (
    <section id="download" className="relative py-20 sm:py-28 px-6 scroll-mt-20 bg-gradient-to-b from-hunter-dark via-hunter-bg to-hunter-dark" aria-labelledby="download-heading">
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-pixel-green/[0.02] to-transparent" aria-hidden="true" />
      <div className="relative z-10 max-w-3xl mx-auto text-center">
        <DuckFootIcon className="w-14 h-14 text-pixel-green mx-auto mb-6 drop-shadow-[0_0_10px_rgba(74,222,128,0.4)]" decorative />

        <h2 id="download-heading" className="font-pixel text-lg sm:text-2xl text-pixel-green text-glow-green mb-3">READY PLAYER ONE?</h2>

        <p className="text-[#6b8f6e] text-lg mb-10 max-w-lg mx-auto">
          Download WisprDuck for free from GitHub. Requires macOS&nbsp;14.2+ (Sonoma).
        </p>

        <Button
          asChild
          size="lg"
          className="font-pixel text-sm tracking-wider bg-pixel-green text-hunter-dark hover:bg-pixel-green/90 border-2 border-pixel-green-dim px-12 py-7 rounded-none pixel-border shadow-[0_0_20px_rgba(74,222,128,0.3)] hover:shadow-[0_0_40px_rgba(74,222,128,0.5)] transition-shadow"
        >
          <a href={`${GITHUB_URL}/releases`} target="_blank" rel="noopener noreferrer">
            <GitHubIcon className="w-6 h-6" />
            INSERT COIN
          </a>
        </Button>

        <p className="font-pixel text-[10px] text-[#6b8f6e]/50 mt-8 tracking-wider">
          APACHE 2.0 LICENSE {'\u00B7'} FREE FOREVER
        </p>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="border-t-2 border-hunter-border py-8 sm:py-10 px-6 bg-hunter-dark" role="contentinfo">
      <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 sm:gap-6">
        <div className="flex items-center gap-2.5 min-w-0">
          <DuckFootIcon className="w-5 h-5 text-pixel-green/50 shrink-0" decorative />
          <span className="font-pixel text-[10px] text-[#6b8f6e]/50 tracking-wider">
            {'WISPRDUCK \u00A9 '}
            {new Date().getFullYear()}
          </span>
        </div>

        <nav aria-label="Social links" className="flex items-center gap-6">
          <a
            href={TWITTER_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-[#6b8f6e]/50 hover:text-pixel-green transition-colors py-2"
          >
            <XIcon className="w-5 h-5" />
            <span className="font-pixel text-[10px] tracking-wider">@KALEPAIL</span>
          </a>
          <a
            href={GITHUB_PROFILE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-[#6b8f6e]/50 hover:text-pixel-green transition-colors py-2"
          >
            <GitHubIcon className="w-5 h-5" />
            <span className="font-pixel text-[10px] tracking-wider">KALEPAIL</span>
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="font-pixel text-[10px] text-[#6b8f6e]/50 hover:text-pixel-green transition-colors tracking-wider py-2"
          >
            SOURCE
          </a>
        </nav>
      </div>
    </footer>
  )
}

function App() {
  return (
    <div className="min-h-screen bg-hunter-dark text-[#e2e8d0] overflow-x-hidden">
      <div className="crt-overlay" aria-hidden="true" />
      <SkipLink />
      <Navbar />
      <main id="main">
        <Hero />
        <HowItWorks />
        <Features />
        <ScoreBoard />
        <Download />
      </main>
      <Footer />
    </div>
  )
}

export default App
