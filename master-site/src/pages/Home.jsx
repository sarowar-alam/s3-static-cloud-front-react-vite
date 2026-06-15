import { Link } from 'react-router-dom'

const stats = [
  { value: '12', label: 'Course Modules' },
  { value: '24', label: 'Live Classes' },
  { value: '80+', label: 'Hours of Content' },
  { value: '15+', label: 'Real-World Projects' },
]

const features = [
  {
    icon: '☁️',
    title: 'AWS Cloud & Networking',
    desc: 'EC2, S3, VPC, IAM, RDS, Route53, ALB, Auto Scaling — build and secure production cloud infrastructure from scratch.',
  },
  {
    icon: '🐳',
    title: 'Docker & Containers',
    desc: 'Containerise a three-tier application, write optimised multi-stage Dockerfiles, and push images to AWS ECR and DockerHub.',
  },
  {
    icon: '⚙️',
    title: 'Kubernetes & Orchestration',
    desc: 'Migrate a full three-tier app to Kubernetes with Ingress, HPA, PVCs, Probes, and blue/green deployment strategies.',
  },
  {
    icon: '🏗️',
    title: 'Terraform & IaC',
    desc: 'Provision and version your entire VPC, compute, load balancer, and RDS stack with Terraform — no more click-ops.',
  },
  {
    icon: '🔄',
    title: 'CI/CD Pipelines',
    desc: 'Automate build, test, and deploy with GitHub Actions and AWS CodePipeline — zero-downtime deployments on every push.',
  },
  {
    icon: '📊',
    title: 'Monitoring & Observability',
    desc: 'Set up Prometheus, Grafana, and Loki to monitor metrics, visualise dashboards, and alert on application health.',
  },
]

const tools = [
  'AWS', 'Docker', 'Kubernetes', 'Terraform', 'GitHub Actions',
  'AWS CodePipeline', 'Prometheus', 'Grafana', 'Loki', 'Nginx',
  'Linux', 'Bash', 'Git', 'ECR', 'RDS', 'ngrok', 'Helm',
]

export default function Home() {
  return (
    <>
      {/* ── Hero ── */}
      <section className="relative bg-gradient-to-br from-slate-900 via-slate-800 to-indigo-950 overflow-hidden">
        {/* Subtle grid overlay */}
        <div
          className="absolute inset-0 opacity-10"
          style={{
            backgroundImage:
              'linear-gradient(rgba(99,102,241,0.4) 1px, transparent 1px), linear-gradient(90deg, rgba(99,102,241,0.4) 1px, transparent 1px)',
            backgroundSize: '48px 48px',
          }}
        />

        <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-24 sm:py-32 lg:py-40">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-indigo-600/20 border border-indigo-500/30 text-indigo-300 text-sm font-medium mb-6">
            <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 animate-pulse" />
            Batch 11 — Now Enrolling via&nbsp;
            <a
              href="https://ostad.app/"
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-2 hover:text-white transition-colors"
            >
              ostad.app
            </a>
          </div>

          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-tight mb-4">
            Mastering DevOps
            <span className="block text-transparent bg-clip-text bg-gradient-to-r from-indigo-400 to-blue-400 mt-1">
              From Fundamentals to Advanced Practices
            </span>
          </h1>

          <p className="text-base text-indigo-300 mb-3 font-medium">
            Instructor:&nbsp;
            <span className="text-white font-semibold">MD Sarowar Alam</span>
            &nbsp;—&nbsp;Lead DevOps Engineer, WPPProduction
          </p>

          <p className="text-lg sm:text-xl text-slate-400 max-w-2xl mb-10 leading-relaxed">
            A hands-on, project-driven program — go from DevOps zero to deploying a
            highly available, auto-scaling three-tier application on AWS with
            Kubernetes, Terraform, and full CI/CD.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 mb-16">
            <a
              href="https://ostad.app/"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-base transition-all shadow-lg shadow-indigo-500/25 hover:shadow-indigo-500/40"
            >
              Enroll on ostad.app
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
              </svg>
            </a>
            <Link
              to="/modules"
              className="inline-flex items-center justify-center gap-2 px-6 py-3.5 rounded-xl border border-slate-600 hover:border-slate-400 text-slate-300 hover:text-white font-semibold text-base transition-all"
            >
              View Curriculum
            </Link>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {stats.map(({ value, label }) => (
              <div
                key={label}
                className="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4 sm:p-5 text-center backdrop-blur-sm"
              >
                <div className="text-2xl sm:text-3xl font-extrabold text-white mb-1">{value}</div>
                <div className="text-slate-400 text-xs sm:text-sm">{label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── What You'll Master ── */}
      <section className="bg-white py-20 sm:py-28">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-14">
            <p className="text-indigo-600 text-sm font-semibold uppercase tracking-wider mb-2">
              Curriculum Highlights
            </p>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900">
              What You&apos;ll Master
            </h2>
            <p className="text-slate-500 mt-4 max-w-xl mx-auto">
              Every topic is taught hands-on. No theory-only lectures — you build,
              break, and fix real systems.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {features.map(({ icon, title, desc }) => (
              <div
                key={title}
                className="flex flex-col gap-4 p-6 rounded-2xl border border-slate-200 hover:border-indigo-200 hover:shadow-lg hover:shadow-indigo-50/80 transition-all bg-white"
              >
                <div className="w-11 h-11 rounded-xl bg-indigo-50 flex items-center justify-center text-xl">
                  {icon}
                </div>
                <h3 className="font-bold text-slate-900 text-base">{title}</h3>
                <p className="text-slate-500 text-sm leading-relaxed">{desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Tech Stack ── */}
      <section className="bg-slate-50 py-16 sm:py-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-slate-400 text-xs uppercase tracking-widest font-semibold mb-8">
            Tools &amp; Technologies You&apos;ll Work With
          </p>
          <div className="flex flex-wrap justify-center gap-3">
            {tools.map((tool) => (
              <span
                key={tool}
                className="px-4 py-2 rounded-full bg-white border border-slate-200 text-slate-700 text-sm font-medium shadow-sm hover:border-indigo-300 hover:text-indigo-700 transition-colors"
              >
                {tool}
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* ── Learning Journey ── */}
      <section className="bg-slate-900 py-16 sm:py-20 border-t border-slate-800">
        <div className="max-w-5xl mx-auto px-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-center">
            {[
              { step: '01', title: 'Foundations', desc: 'Linux, Git, AWS basics, and running your first application in the cloud with ngrok.' },
              { step: '02', title: 'Production Systems', desc: 'Three-tier deployments, VPC networking, load balancers, CI/CD, and monitoring with Prometheus & Grafana.' },
              { step: '03', title: 'Advanced Practices', desc: 'Kubernetes orchestration, Terraform IaC, auto-scaling, CodePipeline, and full observability.' },
            ].map(({ step, title, desc }) => (
              <div key={step} className="p-6">
                <div className="text-indigo-500 font-mono text-sm font-bold mb-2">PHASE {step}</div>
                <h3 className="text-white font-bold text-lg mb-3">{title}</h3>
                <p className="text-slate-500 text-sm leading-relaxed">{desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── CTA Banner ── */}
      <section className="bg-indigo-600 py-16 sm:py-20">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <h2 className="text-3xl sm:text-4xl font-extrabold text-white mb-4">
            Ready to Start Your DevOps Journey?
          </h2>
          <p className="text-indigo-200 text-lg mb-8 max-w-xl mx-auto">
            Join Batch 11 on ostad.app and get hands-on experience building real
            production infrastructure — guided by an active industry practitioner.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <a
              href="https://ostad.app/"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center px-8 py-3.5 rounded-xl bg-white text-indigo-600 font-bold text-base hover:bg-indigo-50 transition-colors shadow-lg"
            >
              Enroll on ostad.app
            </a>
            <Link
              to="/modules"
              className="inline-flex items-center justify-center px-8 py-3.5 rounded-xl border-2 border-white/30 text-white font-bold text-base hover:bg-indigo-500 transition-colors"
            >
              Explore All 12 Modules
            </Link>
          </div>
        </div>
      </section>
    </>
  )
}
