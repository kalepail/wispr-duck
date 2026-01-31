import './App.css'

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

function CircuitPattern() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none opacity-[0.07]" aria-hidden="true">
      <svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="circuit" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
            <path d="M 0 50 H 40 M 60 50 H 100 M 50 0 V 40 M 50 60 V 100" stroke="#3b82f6" strokeWidth="1" fill="none"/>
            <circle cx="50" cy="50" r="4" fill="#3b82f6"/>
            <circle cx="0" cy="50" r="2" fill="#3b82f6"/>
            <circle cx="100" cy="50" r="2" fill="#3b82f6"/>
            <circle cx="50" cy="0" r="2" fill="#3b82f6"/>
            <circle cx="50" cy="100" r="2" fill="#3b82f6"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#circuit)" />
      </svg>
    </div>
  )
}

const features = [
  {
    icon: '\u{1F399}\uFE0F',
    title: 'Auto Mic Detection',
    description: 'Instantly detects when any app activates your microphone. No setup required \u2014 just works.',
  },
  {
    icon: '\u{1F39A}\uFE0F',
    title: 'Smooth Volume Fading',
    description: 'Linear 1-second volume transitions. No harsh jumps \u2014 just buttery-smooth audio ducking.',
  },
  {
    icon: '\u{1F3AF}',
    title: 'Selective Ducking',
    description: 'Duck all audio or pick specific apps. Spotify, Chrome, Discord \u2014 you choose what gets quiet.',
  },
  {
    icon: '\u{1F6E1}\uFE0F',
    title: 'Crash-Safe',
    description: 'Audio auto-restores if WisprDuck quits unexpectedly. Your music never stays muted.',
  },
  {
    icon: '\u26A1',
    title: 'Lightweight',
    description: 'Event-driven Core Audio listeners \u2014 no polling. Minimal CPU usage in your menu bar.',
  },
  {
    icon: '\u{1F527}',
    title: 'Open Source',
    description: 'Apache 2.0 licensed. Inspect, modify, and contribute on GitHub.',
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
    <nav className="fixed top-0 left-0 right-0 z-50 bg-circuit/80 backdrop-blur-lg border-b border-white/10" aria-label="Main navigation">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2 min-w-0 group">
          <DuckFootIcon className="w-7 h-7 text-duck-teal shrink-0 transition-transform group-hover:scale-110" decorative />
          <span className="font-bold text-lg truncate">WisprDuck</span>
        </a>
        <div className="flex items-center gap-4 sm:gap-6">
          <a href="#features" className="text-sm text-white/60 hover:text-white transition-colors hidden sm:block">Features</a>
          <a href="#how-it-works" className="text-sm text-white/60 hover:text-white transition-colors hidden sm:block">How It Works</a>
          <a href="#download" className="text-sm text-white/60 hover:text-white transition-colors hidden sm:block">Download</a>
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="text-white/60 hover:text-white transition-colors" aria-label="WisprDuck on GitHub">
            <GitHubIcon className="w-5 h-5" />
          </a>
          <a href={TWITTER_URL} target="_blank" rel="noopener noreferrer" className="text-white/60 hover:text-white transition-colors" aria-label="@kalepail on X (Twitter)">
            <XIcon className="w-5 h-5" />
          </a>
        </div>
      </div>
    </nav>
  )
}

function Hero() {
  return (
    <section className="relative pt-28 sm:pt-36 pb-20 sm:pb-28 px-6 overflow-hidden" aria-labelledby="hero-heading">
      <CircuitPattern />

      <div className="absolute top-1/4 left-1/4 w-64 sm:w-96 h-64 sm:h-96 bg-duck-teal/10 rounded-full blur-3xl" aria-hidden="true" />
      <div className="absolute bottom-1/4 right-1/4 w-64 sm:w-96 h-64 sm:h-96 bg-duck-purple/10 rounded-full blur-3xl" aria-hidden="true" />

      <div className="relative z-10 text-center max-w-4xl mx-auto">
        <div className="inline-flex items-center gap-2 bg-white/5 border border-white/10 rounded-full px-4 py-1.5 mb-8">
          <span className="w-2 h-2 bg-duck-green rounded-full animate-pulse" aria-hidden="true" />
          <span className="text-sm text-white/70">Free &amp; Open Source for macOS 14.2+</span>
        </div>

        <h1 id="hero-heading" className="text-5xl sm:text-7xl font-black tracking-tight mb-4">
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-duck-teal via-duck-green to-duck-cyan">
            WisprDuck
          </span>
        </h1>

        <p className="text-2xl sm:text-3xl font-mono text-white/50 mb-6">
          {'Shhh\u2026 Ducking volume.'}
        </p>

        <p className="text-lg sm:text-xl text-white/70 max-w-2xl mx-auto mb-10 leading-relaxed">
          A lightweight macOS menu bar app that{' '}
          <strong className="text-white font-semibold">automatically reduces background audio</strong>{' '}
          when your microphone is active. Perfect for voice&#8209;to&#8209;text, video&nbsp;calls, and screen&nbsp;recordings.
        </p>

        <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12 sm:mb-16">
          <a
            href={`${GITHUB_URL}/releases`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 bg-gradient-to-r from-duck-teal to-duck-green text-circuit font-bold px-8 py-4 rounded-xl text-lg shadow-lg shadow-duck-teal/20 transition-transform hover:scale-105 focus-visible:scale-105"
          >
            <GitHubIcon className="w-5 h-5" />
            Download on GitHub
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 bg-white/5 border border-white/20 text-white font-semibold px-8 py-4 rounded-xl text-lg transition-colors hover:bg-white/10 focus-visible:bg-white/10"
          >
            View Source Code
          </a>
        </div>

        <div className="relative max-w-3xl mx-auto rounded-2xl overflow-hidden border border-white/10 shadow-2xl shadow-duck-teal/10">
          <img
            src="/assets/banner-fun-2.png"
            alt="Retro CRT monitor displaying WisprDuck installation at 45% complete, with a cheerful white duck character emerging from the screen, set against a blue circuit board background with a CD-ROM disc"
            className="w-full h-auto block"
            width="1408"
            height="768"
            loading="eager"
            fetchpriority="high"
            decoding="async"
            style={{ aspectRatio: '1408 / 768' }}
          />
        </div>
      </div>
    </section>
  )
}

function HowItWorks() {
  const steps = [
    { num: '01', label: 'Detect', desc: 'Core Audio listener fires when any app activates the default input device.', color: 'text-duck-teal' },
    { num: '02', label: 'Tap', desc: 'Process taps are created for target apps, intercepting their audio output.', color: 'text-duck-green' },
    { num: '03', label: 'Scale', desc: 'Intercepted audio is scaled by your chosen duck level and played through.', color: 'text-duck-cyan' },
    { num: '04', label: 'Restore', desc: `When the mic goes idle, volume ramps back up smoothly over ~1\u00A0second.`, color: 'text-duck-purple' },
  ]

  return (
    <section id="how-it-works" className="relative py-20 sm:py-28 px-6 scroll-mt-20" aria-labelledby="how-heading">
      <div className="max-w-6xl mx-auto">
        <h2 id="how-heading" className="text-3xl sm:text-4xl font-bold text-center mb-4" style={{ textWrap: 'balance' }}>How It Works</h2>
        <p className="text-white/50 text-center mb-12 sm:mb-16 max-w-xl mx-auto">Four simple steps. Zero configuration. Just install and go.</p>

        <ol className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 list-none p-0 m-0">
          {steps.map(step => (
            <li key={step.num} className="relative bg-white/5 border border-white/10 rounded-2xl p-6 transition-colors hover:bg-white/[0.08] group">
              <span className={`text-5xl font-black ${step.color} opacity-20 group-hover:opacity-40 transition-opacity block`} style={{ fontVariantNumeric: 'tabular-nums' }} aria-hidden="true">{step.num}</span>
              <h3 className={`text-xl font-bold mt-3 ${step.color}`}>{step.label}</h3>
              <p className="text-white/60 mt-2 text-sm leading-relaxed">{step.desc}</p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}

function Features() {
  return (
    <section id="features" className="relative py-20 sm:py-28 px-6 scroll-mt-20" aria-labelledby="features-heading">
      <CircuitPattern />
      <div className="relative z-10 max-w-6xl mx-auto">
        <h2 id="features-heading" className="text-3xl sm:text-4xl font-bold text-center mb-4" style={{ textWrap: 'balance' }}>Features</h2>
        <p className="text-white/50 text-center mb-12 sm:mb-16 max-w-xl mx-auto">Built with Core Audio process taps for rock-solid, low-latency audio ducking.</p>

        <ul className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 list-none p-0 m-0">
          {features.map(feature => (
            <li key={feature.title} className="bg-white/5 border border-white/10 rounded-2xl p-6 transition-colors hover:border-duck-teal/30 hover:bg-white/[0.08]">
              <span className="text-3xl mb-3 block" role="img" aria-label={feature.title}>{feature.icon}</span>
              <h3 className="text-lg font-bold mb-2">{feature.title}</h3>
              <p className="text-white/60 text-sm leading-relaxed">{feature.description}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

function Download() {
  return (
    <section id="download" className="relative py-20 sm:py-28 px-6 scroll-mt-20" aria-labelledby="download-heading">
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-duck-teal/5 to-transparent" aria-hidden="true" />
      <div className="relative z-10 max-w-3xl mx-auto text-center">
        <DuckFootIcon className="w-16 h-16 text-duck-teal mx-auto mb-6" decorative />
        <h2 id="download-heading" className="text-3xl sm:text-4xl font-bold mb-4" style={{ textWrap: 'balance' }}>Ready to duck?</h2>
        <p className="text-white/60 text-lg mb-10 max-w-lg mx-auto">
          Download WisprDuck for free from GitHub. Requires macOS&nbsp;14.2+ (Sonoma).
        </p>

        <a
          href={`${GITHUB_URL}/releases`}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-3 bg-gradient-to-r from-duck-teal to-duck-green text-circuit font-bold px-10 py-4 rounded-xl text-lg shadow-lg shadow-duck-teal/20 transition-transform hover:scale-105 focus-visible:scale-105"
        >
          <GitHubIcon className="w-6 h-6" />
          Download Latest Release
        </a>

        <p className="text-white/30 text-sm mt-6">
          Apache 2.0 License {'\u00B7'} Free forever
        </p>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="border-t border-white/10 py-10 sm:py-12 px-6" role="contentinfo">
      <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 sm:gap-6">
        <div className="flex items-center gap-2 min-w-0">
          <DuckFootIcon className="w-5 h-5 text-duck-teal shrink-0" decorative />
          <span className="text-sm text-white/40">
            {'WisprDuck \u00A9 '}
            {new Date().getFullYear()}
          </span>
        </div>

        <nav aria-label="Social links" className="flex items-center gap-6">
          <a
            href={TWITTER_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-sm text-white/40 hover:text-white transition-colors"
          >
            <XIcon className="w-4 h-4" />
            <span>@kalepail</span>
          </a>
          <a
            href={GITHUB_PROFILE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 text-sm text-white/40 hover:text-white transition-colors"
          >
            <GitHubIcon className="w-4 h-4" />
            <span>kalepail</span>
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm text-white/40 hover:text-white transition-colors"
          >
            Source
          </a>
        </nav>
      </div>
    </footer>
  )
}

function App() {
  return (
    <div className="min-h-screen bg-circuit text-white overflow-x-hidden">
      <SkipLink />
      <Navbar />
      <main id="main">
        <Hero />
        <HowItWorks />
        <Features />
        <Download />
      </main>
      <Footer />
    </div>
  )
}

export default App
