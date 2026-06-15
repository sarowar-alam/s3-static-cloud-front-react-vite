const objectives = [
  'Run a DevOps demo application locally and expose it over ngrok',
  'Master Git workflows, branching strategies, and collaborative PR reviews',
  'Deploy and manage a three-tier application on an AWS EC2 instance',
  'Secure infrastructure with AWS VPC, private subnets, and load balancers',
  'Automate CI/CD pipelines with GitHub Actions and AWS CodePipeline',
  'Monitor systems with Prometheus, Grafana, and Loki log aggregation',
  'Provision and version-control cloud infrastructure with Terraform',
  'Build auto-scaling, self-healing systems with AWS Auto Scaling Groups',
  'Containerise a three-tier application with Docker and push to ECR',
  'Orchestrate workloads on Kubernetes with Ingress, HPA, and rolling updates',
]

const highlights = [
  { label: 'Duration', value: '12 Weeks' },
  { label: 'Format', value: 'Live + Recorded' },
  { label: 'Modules', value: '12 Modules' },
  { label: 'Live Classes', value: '24 Classes' },
]

const instructorTags = [
  'Lead DevOps Engineer',
  'WPPProduction',
  'AWS Certified',
  'Industry Practitioner',
]

export default function About() {
  return (
    <>
      {/* ── Page Hero ── */}
      <section className="bg-gradient-to-br from-slate-900 to-slate-800 py-16 sm:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-indigo-400 text-sm font-semibold uppercase tracking-wider mb-3">
            About the Program
          </p>
          <h1 className="text-3xl sm:text-5xl font-extrabold text-white mb-5">
            Mastering DevOps: From Fundamentals to Advanced Practices
          </h1>
          <p className="text-slate-400 text-lg max-w-2xl mx-auto leading-relaxed">
            A 12-module, cohort-based program on&nbsp;
            <a href="https://ostad.app/" target="_blank" rel="noopener noreferrer" className="text-indigo-400 underline underline-offset-2 hover:text-white transition-colors">ostad.app</a>
            &nbsp;— built to fast-track your journey from fundamentals to deploying
            production-grade systems on AWS.
          </p>
        </div>
      </section>

      {/* ── About the program ── */}
      <section className="bg-white py-20 sm:py-28">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-14 items-center">

            <div>
              <p className="text-indigo-600 text-sm font-semibold uppercase tracking-wider mb-3">
                The Program
              </p>
              <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mb-6">
                Why DevOps Batch&nbsp;11?
              </h2>
              <p className="text-slate-600 leading-relaxed mb-5">
                DevOps is one of the fastest-growing disciplines in tech. Companies
                need engineers who can bridge development and operations — and that is
                exactly what this program trains you to do.
              </p>
              <p className="text-slate-600 leading-relaxed mb-10">
                In 12 intensive modules and 24 live classes, you will go from setting up
                your first DevOps demo app over ngrok to deploying a fully automated,
                monitored, auto-scaling three-tier application on AWS with Kubernetes
                and Terraform. Every session includes hands-on labs.
              </p>
              <div className="grid grid-cols-2 gap-4">
                {highlights.map(({ label, value }) => (
                  <div key={label} className="bg-slate-50 rounded-xl p-5 border border-slate-100">
                    <div className="text-indigo-600 font-extrabold text-xl mb-1">{value}</div>
                    <div className="text-slate-500 text-sm">{label}</div>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-slate-900 rounded-2xl p-8 sm:p-10">
              <h3 className="text-white font-bold text-xl mb-6">What You Will Achieve (By Module)</h3>
              <ul className="space-y-4">
                {objectives.map((item) => (
                  <li key={item} className="flex items-start gap-3 text-slate-300 text-sm leading-relaxed">
                    <svg
                      className="w-5 h-5 text-indigo-400 shrink-0 mt-0.5"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    {item}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* ── Instructor ── */}
      <section className="bg-slate-50 py-20 sm:py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <p className="text-indigo-600 text-sm font-semibold uppercase tracking-wider mb-2">
              Your Instructors
            </p>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900">
              Learn From Practitioners
            </h2>
          </div>
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-8 sm:p-10">
            <div className="flex flex-col sm:flex-row gap-6 items-start">
              <div className="w-16 h-16 rounded-2xl bg-indigo-600 flex items-center justify-center text-2xl shrink-0">
                👨‍💻
              </div>
              <div>
                <h3 className="text-slate-900 font-bold text-xl mb-1">
                  MD Sarowar Alam
                </h3>
                <p className="text-indigo-600 text-sm font-medium mb-4">
                  Lead DevOps Engineer — WPPProduction
                </p>
                <p className="text-slate-600 leading-relaxed mb-6">
                  Sarowar is an active Lead DevOps Engineer at WPPProduction with deep expertise
                  in cloud infrastructure, SRE, and platform engineering at scale. He brings
                  real-world scenarios from production systems to every session — not textbook
                  examples. This course is structured around the same tools and practices he
                  uses in production every day.
                </p>
                <div className="flex flex-wrap gap-2">
                  {instructorTags.map((tag) => (
                    <span
                      key={tag}
                      className="px-3 py-1 rounded-full bg-indigo-50 border border-indigo-100 text-indigo-700 text-xs font-medium"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </>
  )
}
