import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Code } from 'pixelarticons/react/Code'
import { Download as DownloadIcon } from 'pixelarticons/react/Download'
import { Mic } from 'pixelarticons/react/Mic'
import { Shield } from 'pixelarticons/react/Shield'
import { Sliders } from 'pixelarticons/react/Sliders'
import { Volume2 } from 'pixelarticons/react/Volume2'
import { Zap } from 'pixelarticons/react/Zap'
// The release skill bumps site/package.json, so the download link follows each release.
import { version as VERSION } from '../package.json'

const GITHUB_URL = 'https://github.com/kalepail/wispr-duck'
const TWITTER_URL = 'https://x.com/kalepail'
const GITHUB_PROFILE_URL = 'https://github.com/kalepail'
const DOWNLOAD_URL = `${GITHUB_URL}/releases/download/v${VERSION}/WisprDuck-${VERSION}.zip`
const RELEASE_NOTES_URL = `${GITHUB_URL}/releases/tag/v${VERSION}`
const RELEASES_URL = `${GITHUB_URL}/releases`

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
      <defs>
        <mask id="duck-foot-cutout">
          <path d="M 100,195 C 85,168 28,95 8,30 C 2,16 8,12 16,20 C 28,35 45,52 56,64 C 64,72 74,72 84,60 C 90,46 95,22 100,4 C 105,22 110,46 116,60 C 126,72 136,72 144,64 C 155,52 172,35 184,20 C 192,12 198,16 192,30 C 172,95 115,168 100,195 Z" fill="white"/>
          <path d="M 100,158 C 90,125 78,92 64,68" stroke="black" strokeWidth="5" strokeLinecap="round"/>
          <path d="M 100,158 C 110,125 122,92 136,68" stroke="black" strokeWidth="5" strokeLinecap="round"/>
        </mask>
      </defs>
      <path d="M 100,195 C 85,168 28,95 8,30 C 2,16 8,12 16,20 C 28,35 45,52 56,64 C 64,72 74,72 84,60 C 90,46 95,22 100,4 C 105,22 110,46 116,60 C 126,72 136,72 144,64 C 155,52 172,35 184,20 C 192,12 198,16 192,30 C 172,95 115,168 100,195 Z" fill="currentColor" mask="url(#duck-foot-cutout)"/>
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
    Icon: Mic,
    title: 'Per-App Triggers',
    description: 'Pick the apps that trigger ducking. Wispr Flow is on by default, and Granola Voice Typing is one switch away.',
    color: 'text-pixel-green',
  },
  {
    Icon: Volume2,
    title: 'Smooth Restore',
    description: 'Audio ducks the moment your mic turns on, then fades back up over about 1 second when you stop talking.',
    color: 'text-pixel-orange',
  },
  {
    Icon: Sliders,
    title: 'Selective Ducking',
    description: 'Duck all audio, or only the apps you pick. Spotify, Chrome, Arc, Safari and 16 more are ready out of the box.',
    color: 'text-pixel-blue',
  },
  {
    Icon: Shield,
    title: 'Crash-Safe',
    description: 'Ducked apps are muted at the source by Core Audio, so their sound comes back even if WisprDuck quits unexpectedly.',
    color: 'text-pixel-yellow',
  },
  {
    Icon: Zap,
    title: 'Lightweight',
    description: 'Core Audio tells WisprDuck when your mic changes. Nothing polls while you are idle, so it sits in your menu bar at near-zero CPU.',
    color: 'text-pixel-teal',
  },
  {
    Icon: Code,
    title: 'Open Source',
    description: 'Apache 2.0 licensed. Read the code, change it, and contribute on GitHub.',
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

const navLink = 'font-pixel text-[10px] text-pixel-green/70 hover:text-pixel-green tracking-wide py-3 select-none'
const iconLink = 'text-pixel-green/70 hover:text-pixel-green p-2.5 -m-0.5'

function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-40 bg-hunter-dark/90 backdrop-blur-sm border-b-2 border-hunter-border" aria-label="Main navigation">
      <div className="max-w-6xl mx-auto px-5 sm:px-6 h-16 flex items-center justify-between gap-4">
        <a href="#" className="flex items-center gap-2.5 min-w-0 group py-2 select-none" aria-label="WisprDuck home">
          <DuckFootIcon className="w-7 h-7 text-pixel-green shrink-0" decorative />
          <span className="font-pixel text-sm text-pixel-green tracking-wide">WISPRDUCK</span>
        </a>
        <div className="flex items-center gap-4 sm:gap-6">
          <a href="#how-it-works" className={`${navLink} hidden sm:block`}>HOW IT WORKS</a>
          <a href="#features" className={`${navLink} hidden sm:block`}>FEATURES</a>
          <a href="#download" className={navLink}>DOWNLOAD</a>
          <Separator orientation="vertical" className="h-5 bg-hunter-border hidden sm:block" />
          <div className="flex items-center gap-1 sm:gap-3">
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className={iconLink} aria-label="WisprDuck on GitHub" title="WisprDuck on GitHub">
              <GitHubIcon className="w-6 h-6 shrink-0" />
            </a>
            <a href={TWITTER_URL} target="_blank" rel="noopener noreferrer" className={`${iconLink} hidden min-[400px]:block`} aria-label="@kalepail on X" title="@kalepail on X">
              <XIcon className="w-6 h-6 shrink-0" />
            </a>
          </div>
        </div>
      </div>
    </nav>
  )
}

const primaryButton = 'font-pixel text-sm tracking-wider bg-pixel-green text-hunter-dark hover:bg-[#6ee7a0] border-2 border-pixel-green-dim px-8 sm:px-10 py-7 rounded-none pixel-border shadow-[0_0_20px_rgba(74,222,128,0.3)] select-none'

function ReleaseMeta() {
  return (
    <p className="text-sm text-ink-3">
      {`Version ${VERSION} · macOS 14.2+ · Free`}
      {' · '}
      <a href={RELEASE_NOTES_URL} target="_blank" rel="noopener noreferrer" className="text-ink-2 underline underline-offset-4 decoration-ink-3 hover:text-pixel-green hover:decoration-pixel-green">
        Release notes
      </a>
    </p>
  )
}

function Hero() {
  return (
    <section className="relative pt-28 sm:pt-36 pb-24 sm:pb-32 px-5 sm:px-6 overflow-hidden bg-gradient-to-b from-sky-top via-hunter-dark to-hunter-bg" aria-labelledby="hero-heading">
      <PixelStars />
      <CrosshairDecor />

      {/* Pixel glow orbs */}
      <div className="absolute top-1/3 left-1/4 w-48 sm:w-72 h-48 sm:h-72 bg-pixel-green/5 rounded-full blur-3xl" aria-hidden="true" />
      <div className="absolute bottom-1/4 right-1/5 w-48 sm:w-72 h-48 sm:h-72 bg-pixel-orange/5 rounded-full blur-3xl" aria-hidden="true" />

      <div className="relative z-10 text-center max-w-4xl mx-auto">
        <Badge variant="outline" className="mb-8 border-pixel-green/30 bg-hunter-card/50 text-pixel-green font-pixel text-[10px] tracking-wider px-4 py-2 gap-2.5 rounded-none select-none">
          <span className="w-2 h-2 bg-pixel-green rounded-none animate-blink inline-block" aria-hidden="true" />
          FREE &amp; OPEN SOURCE
        </Badge>

        <h1 id="hero-heading" className="font-pixel text-3xl sm:text-5xl lg:text-6xl tracking-tight mb-6 text-glow-green text-pixel-green leading-relaxed">
          WISPRDUCK
        </h1>

        <p className="font-pixel text-sm sm:text-base text-pixel-orange mb-5 text-glow-orange tracking-wide">
          {'Shhh… Ducking volume.'}
        </p>

        <p className="text-base sm:text-lg text-ink-2 max-w-[38rem] mx-auto mb-10 leading-relaxed text-balance">
          A lightweight macOS menu bar app that{' '}
          <strong className="text-pixel-green font-semibold">turns down background audio</strong>{' '}
          while your mic is on. Built for{' '}
          <strong className="text-pixel-orange font-semibold">Wispr Flow</strong>, works with Granola Voice Typing, and
          fits video&nbsp;calls and screen&nbsp;recordings too.
        </p>

        <div className="flex flex-col sm:flex-row gap-4 justify-center mb-5">
          <Button asChild size="lg" className={primaryButton}>
            <a href={DOWNLOAD_URL}>
              <DownloadIcon className="size-6 shrink-0" aria-hidden="true" />
              DOWNLOAD FOR MAC
            </a>
          </Button>
          <Button
            asChild
            variant="outline"
            size="lg"
            className="font-pixel text-sm tracking-wider border-2 border-hunter-border text-pixel-green/80 hover:text-pixel-green hover:border-pixel-green/40 bg-hunter-card/30 px-8 sm:px-10 py-7 rounded-none select-none"
          >
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer">
              VIEW SOURCE
            </a>
          </Button>
        </div>

        <div className="mb-12 sm:mb-16">
          <ReleaseMeta />
        </div>

        {/* Main banner showcase */}
        <div className="relative max-w-3xl mx-auto">
          <div className="absolute -inset-1 bg-gradient-to-b from-pixel-green/20 via-pixel-orange/10 to-transparent blur-sm" aria-hidden="true" />
          <div className="relative border-2 border-hunter-border overflow-hidden bg-hunter-dark">
            <img
              src="/banner-fun-3.png"
              alt="Four retro pixel art panels of a duck with headphones: installing, loading the mic, ready, and press start to install"
              width="1408"
              height="768"
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
    { num: '01', label: 'DETECT', desc: 'A trigger app turns on your mic. Pick the apps, or let any app count.', color: 'text-pixel-green', border: 'border-pixel-green/30', glow: 'shadow-[0_0_10px_rgba(74,222,128,0.15)]' },
    { num: '02', label: 'TAP', desc: 'WisprDuck takes over the sound of the apps you chose to duck.', color: 'text-pixel-orange', border: 'border-pixel-orange/30', glow: 'shadow-[0_0_10px_rgba(251,146,60,0.15)]' },
    { num: '03', label: 'DUCK', desc: 'Their audio keeps playing at your duck level, 10% by default.', color: 'text-pixel-blue', border: 'border-pixel-blue/30', glow: 'shadow-[0_0_10px_rgba(56,189,248,0.15)]' },
    { num: '04', label: 'RESTORE', desc: 'Your mic turns off, and the volume fades back up over about 1 second.', color: 'text-pixel-yellow', border: 'border-pixel-yellow/30', glow: 'shadow-[0_0_10px_rgba(250,204,21,0.15)]' },
  ]

  return (
    <section id="how-it-works" className="relative py-20 sm:py-28 px-5 sm:px-6 scroll-mt-16 bg-hunter-bg" aria-labelledby="how-heading">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-12 sm:mb-16">
          <h2 id="how-heading" className="font-pixel text-lg sm:text-2xl text-pixel-green text-glow-green mb-4">HOW IT WORKS</h2>
          <p className="text-ink-2 max-w-xl mx-auto text-balance">Four steps, every time you talk. You set it up once.</p>
        </div>

        <ol className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 list-none p-0 m-0">
          {steps.map(step => (
            <li key={step.num}>
              <Card className={`bg-hunter-card/60 border-2 ${step.border} rounded-none pixel-border ${step.glow} h-full`}>
                <CardContent>
                  <span className={`font-pixel text-3xl ${step.color} opacity-40 block select-none`} aria-hidden="true">{step.num}</span>
                  <h3 className={`font-pixel text-xs mt-3 ${step.color} tracking-wider`}>{step.label}</h3>
                  <p className="text-ink-2 mt-3 text-sm leading-relaxed">{step.desc}</p>
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
    <section id="features" className="relative py-20 sm:py-28 px-5 sm:px-6 scroll-mt-16 bg-hunter-dark" aria-labelledby="features-heading">
      <CrosshairDecor />
      <div className="relative z-10 max-w-6xl mx-auto">
        <div className="text-center mb-12 sm:mb-16">
          <h2 id="features-heading" className="font-pixel text-lg sm:text-2xl text-pixel-orange text-glow-orange mb-4">POWER-UPS</h2>
          <p className="text-ink-2 max-w-xl mx-auto text-balance">Built on Core Audio process taps, so ducking is fast and stays out of your way.</p>
        </div>

        <dl className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 m-0">
          {features.map(feature => {
            const FeatureIcon = feature.Icon
            return (
              <Card key={feature.title} className="bg-hunter-card/40 border-2 border-hunter-border rounded-none pixel-border h-full gap-0">
                <CardContent>
                  <FeatureIcon className={`size-6 shrink-0 ${feature.color}`} aria-hidden="true" />
                  <dt className={`font-pixel text-xs tracking-wider mt-4 mb-3 ${feature.color}`}>{feature.title.toUpperCase()}</dt>
                  <dd className="text-ink-2 text-sm leading-relaxed m-0">{feature.description}</dd>
                </CardContent>
              </Card>
            )
          })}
        </dl>
      </div>
    </section>
  )
}

function ScoreBoard() {
  const stats = [
    { label: 'CPU USAGE', value: '~0%', note: 'No polling while idle' },
    { label: 'RESTORE', value: '~1s', note: 'Smooth fade back up' },
    { label: 'PRICE', value: 'FREE', note: 'Apache 2.0 license' },
    { label: 'REQUIRES', value: '14.2+', note: 'macOS Sonoma or later' },
  ]

  return (
    <section className="py-16 sm:py-20 px-5 sm:px-6 bg-hunter-bg border-y-2 border-hunter-border" aria-labelledby="scores-heading">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-10">
          <h2 id="scores-heading" className="font-pixel text-base sm:text-lg text-pixel-yellow tracking-wider">HIGH SCORES</h2>
        </div>
        <dl className="grid grid-cols-2 lg:grid-cols-4 gap-x-4 gap-y-8 m-0">
          {stats.map(stat => (
            <div key={stat.label} className="text-center py-2 flex flex-col">
              <dt className="font-pixel text-[10px] sm:text-xs text-pixel-orange tracking-wider mb-2 order-2">{stat.label}</dt>
              <dd className="font-pixel text-2xl sm:text-3xl text-pixel-green text-glow-green mb-3 order-1 m-0">{stat.value}</dd>
              <dd className="text-xs text-ink-3 order-3 m-0">{stat.note}</dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  )
}

function Download() {
  return (
    <section id="download" className="relative py-20 sm:py-28 px-5 sm:px-6 scroll-mt-16 bg-gradient-to-b from-hunter-dark via-hunter-bg to-hunter-dark" aria-labelledby="download-heading">
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-pixel-green/[0.02] to-transparent" aria-hidden="true" />
      <div className="relative z-10 max-w-3xl mx-auto text-center">
        <DuckFootIcon className="w-14 h-14 text-pixel-green mx-auto mb-6 drop-shadow-[0_0_10px_rgba(74,222,128,0.4)]" decorative />

        <h2 id="download-heading" className="font-pixel text-lg sm:text-2xl text-pixel-green text-glow-green mb-4">READY PLAYER ONE?</h2>

        <p className="text-ink-2 text-lg mb-10 max-w-md mx-auto text-balance">
          Get WisprDuck {VERSION} for free. It runs on macOS&nbsp;14.2 (Sonoma) or later.
        </p>

        <Button asChild size="lg" className={`${primaryButton} px-10 sm:px-12`}>
          <a href={DOWNLOAD_URL}>
            <DownloadIcon className="size-6 shrink-0" aria-hidden="true" />
            DOWNLOAD FOR MAC
          </a>
        </Button>

        <p className="text-sm text-ink-3 mt-6">
          <a href={RELEASE_NOTES_URL} target="_blank" rel="noopener noreferrer" className="text-ink-2 underline underline-offset-4 decoration-ink-3 hover:text-pixel-green hover:decoration-pixel-green">
            {`What’s new in ${VERSION}`}
          </a>
          {' · '}
          <a href={RELEASES_URL} target="_blank" rel="noopener noreferrer" className="text-ink-2 underline underline-offset-4 decoration-ink-3 hover:text-pixel-green hover:decoration-pixel-green">
            All releases
          </a>
        </p>
      </div>
    </section>
  )
}

function Footer() {
  const footerLink = 'flex items-center gap-2 text-ink-3 hover:text-pixel-green py-3 select-none'
  return (
    <footer className="border-t-2 border-hunter-border py-8 sm:py-10 px-5 sm:px-6 bg-hunter-dark">
      <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 sm:gap-6">
        <div className="flex items-center gap-2.5 min-w-0 select-none">
          <DuckFootIcon className="w-5 h-5 text-pixel-green/70 shrink-0" decorative />
          <span className="font-pixel text-[10px] text-ink-3 tracking-wider">
            {'WISPRDUCK © '}
            {new Date().getFullYear()}
          </span>
        </div>

        <nav aria-label="Social links" className="flex items-center gap-6">
          <a href={TWITTER_URL} target="_blank" rel="noopener noreferrer" className={footerLink}>
            <XIcon className="w-5 h-5 shrink-0" />
            <span className="font-pixel text-[10px] tracking-wider">@KALEPAIL</span>
          </a>
          <a href={GITHUB_PROFILE_URL} target="_blank" rel="noopener noreferrer" className={footerLink}>
            <GitHubIcon className="w-5 h-5 shrink-0" />
            <span className="font-pixel text-[10px] tracking-wider">KALEPAIL</span>
          </a>
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className={`${footerLink} font-pixel text-[10px] tracking-wider`}>
            SOURCE
          </a>
        </nav>
      </div>
    </footer>
  )
}

function App() {
  return (
    <div className="min-h-screen bg-hunter-dark text-ink overflow-x-hidden">
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
