import { Link } from 'react-router-dom'

const contactCards = [
  {
    icon: '🌐',
    title: 'Enroll on ostad.app',
    value: 'ostad.app',
    href: 'https://ostad.app/',
  },
  {
    icon: '📧',
    title: 'Email',
    value: 'info@ostaddevops.click',
    href: 'mailto:info@ostaddevops.click',
  },
  {
    icon: '💬',
    title: 'Community',
    value: 'WhatsApp, Facebook & Discord groups',
    href: '#',
  },
]

const faqs = [
  {
    q: 'Do I need prior experience?',
    a: 'Basic familiarity with the command line helps, but beginners are welcome. We start from DevOps fundamentals and build up progressively through 12 modules.',
  },
  {
    q: 'Are the sessions live or recorded?',
    a: 'All sessions are live with the cohort — 24 live classes across 12 modules. Full recordings are available so you never miss anything.',
  },
  {
    q: 'Where does the course run?',
    a: 'The course is hosted on ostad.app. You can enroll and access all materials, recordings, and resources directly there.',
  },
  {
    q: 'How is the course structured?',
    a: 'Each module has two live classes with hands-on labs, and a defined project goal. Topics build on each other progressively, culminating in a full Kubernetes deployment on AWS.',
  },
  {
    q: 'What tools and accounts do I need?',
    a: 'A laptop, a GitHub account, and an AWS Free Tier account. We walk you through setting up everything else in Module 1.',
  },
  {
    q: 'Who is the instructor?',
    a: 'MD Sarowar Alam, Lead DevOps Engineer at WPPProduction. He teaches from real production experience, not textbook examples.',
  },
]

export default function Contact() {
  return (
    <>
      {/* ── Page Hero ── */}
      <section className="bg-gradient-to-br from-slate-900 to-slate-800 py-16 sm:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-indigo-400 text-sm font-semibold uppercase tracking-wider mb-3">
            Get in Touch
          </p>
          <h1 className="text-3xl sm:text-5xl font-extrabold text-white mb-5">
            Enroll in Batch&nbsp;11
          </h1>
          <p className="text-slate-400 text-lg max-w-xl mx-auto leading-relaxed">
            Join <strong className="text-white">Mastering DevOps: From Fundamentals to Advanced Practices</strong> on&nbsp;
            <a href="https://ostad.app/" target="_blank" rel="noopener noreferrer" className="text-indigo-400 underline underline-offset-2 hover:text-white transition-colors">ostad.app</a>.
            Reach out with any questions — we respond within 24 hours.
          </p>
        </div>
      </section>

      {/* ── Contact cards + CTA ── */}
      <section className="bg-white py-16 sm:py-24">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">

          {/* Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-14">
            {contactCards.map(({ icon, title, value, href }) => (
              <a
                key={title}
                href={href}
                className="group flex flex-col items-center text-center p-7 rounded-2xl border border-slate-200 hover:border-indigo-200 hover:shadow-lg hover:shadow-indigo-50/60 transition-all bg-white"
              >
                <div className="w-14 h-14 rounded-2xl bg-indigo-50 flex items-center justify-center text-2xl mb-4 group-hover:bg-indigo-100 transition-colors">
                  {icon}
                </div>
                <h3 className="font-bold text-slate-900 mb-1">{title}</h3>
                <p className="text-slate-500 text-sm">{value}</p>
              </a>
            ))}
          </div>

          {/* Enroll CTA */}
          <div className="bg-gradient-to-br from-indigo-600 to-indigo-700 rounded-2xl p-8 sm:p-12 text-center mb-16 shadow-xl shadow-indigo-500/20">
            <h2 className="text-2xl sm:text-3xl font-extrabold text-white mb-4">
              Enroll in Batch 11 — on ostad.app
            </h2>
            <p className="text-indigo-200 mb-8 max-w-md mx-auto">
              The course is hosted on ostad.app. Click below to enroll or
              review the full curriculum before signing up.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="https://ostad.app/"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center px-8 py-3.5 rounded-xl bg-white text-indigo-600 font-bold hover:bg-indigo-50 transition-colors"
              >
                Enroll on ostad.app
              </a>
              <Link
                to="/modules"
                className="inline-flex items-center justify-center px-8 py-3.5 rounded-xl border-2 border-white/30 text-white font-bold hover:bg-indigo-500 transition-colors"
              >
                Review Curriculum
              </Link>
            </div>
          </div>

          {/* FAQ */}
          <div>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 text-center mb-8">
              Frequently Asked Questions
            </h2>
            <div className="space-y-3">
              {faqs.map(({ q, a }) => (
                <details
                  key={q}
                  className="group bg-slate-50 border border-slate-200 rounded-xl overflow-hidden"
                >
                  <summary className="flex items-center justify-between w-full px-6 py-4 cursor-pointer text-slate-900 font-semibold text-sm sm:text-base list-none select-none">
                    {q}
                    <svg
                      className="w-5 h-5 text-slate-400 group-open:rotate-180 transition-transform shrink-0 ml-4"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M19 9l-7 7-7-7"
                      />
                    </svg>
                  </summary>
                  <div className="px-6 pb-5 text-slate-600 text-sm leading-relaxed border-t border-slate-200 pt-4">
                    {a}
                  </div>
                </details>
              ))}
            </div>
          </div>
        </div>
      </section>
    </>
  )
}
