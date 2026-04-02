const modules = [
  {
    number: '01',
    title: 'Introduction to DevOps',
    goal: 'Set up project locally and expose it over ngrok.',
    classes: [
      { label: 'Class 01', topics: ['Course overview & onboarding', 'Cloud & Git repo setup', 'Community channels (WhatsApp, Discord)', 'Run DevOps demo app + expose via ngrok'] },
      { label: 'Class 02', topics: ['DevOps Engineering & SDLC', 'The DevOps value proposition', 'Pros & cons of DevOps roles', 'Prerequisites: SWE, networking, soft skills'] },
    ],
    icon: '🚀',
    accent: 'from-indigo-400 to-purple-500',
  },
  {
    number: '02',
    title: 'Git',
    goal: 'Fork a repo and deploy it to Heroku / Render or similar platform.',
    classes: [
      { label: 'Class 01', topics: ['Other VCS systems', 'Git advanced branching', 'Repository roles', 'Restricting branch/history deletion'] },
      { label: 'Class 02', topics: ['Forking workflow', 'Remote upstream setup', 'Pull requests', 'Deploying repo to Heroku/Render'] },
    ],
    icon: '🔀',
    accent: 'from-orange-400 to-red-500',
  },
  {
    number: '03',
    title: 'Basic Cloud & Linux',
    goal: 'Set up Nginx on AWS EC2 with DNS, SSL, and basic Linux system management.',
    classes: [
      { label: 'Class 01', topics: ['AWS EC2 introduction', 'Security Groups & Key Pairs', 'Basic Linux commands', 'Package Manager (apt) & systemctl'] },
      { label: 'Class 02', topics: ['Nginx installation & configuration', 'Route 53 & DNS setup', 'SSL with Certbot', 'Automating with Cron jobs'] },
    ],
    icon: '🐧',
    accent: 'from-yellow-400 to-orange-500',
  },
  {
    number: '04',
    title: 'Deploying a Three-Tier Application',
    goal: 'Deploy and manage a production-ready three-tier application on AWS.',
    classes: [
      { label: 'Class 01', topics: ['Technology stack overview', 'Database deep dive', 'Implement database & backend tools', 'Backend architecture setup'] },
      { label: 'Class 02', topics: ['Frontend architecture', 'AWS deployment walkthrough', 'Updating the application', 'Full architecture review & automation guide'] },
    ],
    icon: '🏛️',
    accent: 'from-cyan-400 to-blue-500',
  },
  {
    number: '05',
    title: 'CI/CD with GitHub Actions',
    goal: 'Build a secure, automated CI/CD pipeline with zero-downtime deployments.',
    classes: [
      { label: 'Class 01', topics: ['CI/CD concepts & benefits', 'GitHub Actions architecture', 'First pipeline creation', 'YAML syntax & debugging failures'] },
      { label: 'Class 02', topics: ['SSH actions to EC2', 'Secrets management', 'Zero-downtime deployments', 'Deployment logs & rollbacks'] },
    ],
    icon: '🔄',
    accent: 'from-green-400 to-emerald-600',
  },
  {
    number: '06',
    title: 'Monitoring (Prometheus, Grafana & Loki)',
    goal: 'Set up monitoring and alerting for the three-tier application.',
    classes: [
      { label: 'Class 01', topics: ['Why monitoring matters', 'Prometheus setup on EC2', 'Node Exporter deep dive', 'PromQL (Prometheus Query Language)'] },
      { label: 'Class 02', topics: ['Grafana setup & data sources', 'Custom dashboards', 'Application metrics (API, frontend, DB)', 'Alerts for application health'] },
    ],
    icon: '📊',
    accent: 'from-pink-400 to-rose-500',
  },
  {
    number: '07',
    title: 'AWS VPC & Networking',
    goal: 'Secure the three-tier app using AWS VPC, private networking, and load balancers.',
    classes: [
      { label: 'Class 01', topics: ['Custom VPC design', 'Public & private subnets', 'Internet Gateway & Route Tables', 'NAT Gateway, Security Groups per tier'] },
      { label: 'Class 02', topics: ['Application Load Balancer (ALB) setup', 'Target Groups configuration', 'Fully private three-tier architecture', 'Network security best practices'] },
    ],
    icon: '🔐',
    accent: 'from-violet-500 to-purple-600',
  },
  {
    number: '08',
    title: 'Terraform & Infrastructure as Code',
    goal: 'Automate and version-control three-tier infrastructure using Terraform.',
    classes: [
      { label: 'Class 01', topics: ['IaC introduction & Terraform setup', 'First EC2 instance with Terraform', 'Terraform modules & security', 'Remote state management (S3)'] },
      { label: 'Class 02', topics: ['VPC, subnets & networking with Terraform', 'Load Balancer & Target Groups as code', 'Bastion host for secure SSH', 'Managing state & outputs'] },
    ],
    icon: '🏗️',
    accent: 'from-purple-500 to-indigo-600',
  },
  {
    number: '09',
    title: 'High Availability & Auto Scaling',
    goal: 'Build a cloud-native, highly available, auto-scaling system with CI/CD and IaC.',
    classes: [
      { label: 'Class 01', topics: ['Auto Scaling architecture', 'Creating AMI & Launch Templates', 'Scaling policies (Target Tracking, Step)', 'Health checks & self-healing'] },
      { label: 'Class 02', topics: ['CI/CD challenges with ASGs', 'AWS CodePipeline for Auto Scaling Groups', 'Blue/Green deployment strategy', 'Automating pipeline creation with Terraform'] },
    ],
    icon: '⚡',
    accent: 'from-yellow-400 to-amber-500',
  },
  {
    number: '10',
    title: 'Dockerising the Three-Tier Application',
    goal: 'Migrate the three-tier app to Docker with CI/CD, logging, and monitoring.',
    classes: [
      { label: 'Class 01', topics: ['Docker architecture & vs VMs', 'Multi-stage Dockerfiles', 'Containerise frontend & backend', 'Push images to DockerHub & AWS ECR'] },
      { label: 'Class 02', topics: ['Docker Compose for the full stack', 'Migrating CI/CD from VMs to Docker', 'Loki for Docker container logs', 'Prometheus & Grafana for containers'] },
    ],
    icon: '🐳',
    accent: 'from-cyan-500 to-blue-600',
  },
  {
    number: '11',
    title: 'Kubernetes Fundamentals',
    goal: 'Learn Kubernetes fundamentals by deploying and exposing an Nginx application.',
    classes: [
      { label: 'Class 01', topics: ['Kubernetes architecture (master & worker)', 'Control plane & node components', 'Pods, ReplicaSets, Deployments, Services', 'Namespaces for resource isolation'] },
      { label: 'Class 02', topics: ['ConfigMaps & Secrets', 'Rolling updates & rollbacks', 'Scaling applications manually', 'Troubleshooting with kubectl'] },
    ],
    icon: '⚙️',
    accent: 'from-blue-500 to-indigo-600',
  },
  {
    number: '12',
    title: 'Migrating to Kubernetes',
    goal: 'Migrate the three-tier app from Docker Compose to production-ready Kubernetes.',
    classes: [
      { label: 'Class 01', topics: ['PostgreSQL on Kubernetes (PV, PVC, StatefulSets)', 'Backend migration & ClusterIP services', 'ConfigMaps & Secrets for Module 4 app', 'Database migration strategies'] },
      { label: 'Class 02', topics: ['Nginx Ingress Controller setup', 'Horizontal Pod Autoscaler (HPA)', 'Liveness & Readiness probes', 'Blue/Green & Canary deployment strategies'] },
    ],
    icon: '🛸',
    accent: 'from-teal-400 to-cyan-600',
  },
]

export default function Modules() {
  return (
    <>
      {/* ── Page Hero ── */}
      <section className="bg-gradient-to-br from-slate-900 to-slate-800 py-16 sm:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-indigo-400 text-sm font-semibold uppercase tracking-wider mb-3">
            Curriculum
          </p>
          <h1 className="text-3xl sm:text-5xl font-extrabold text-white mb-5">
            Course Modules
          </h1>
          <p className="text-slate-400 text-lg max-w-2xl mx-auto leading-relaxed">
            12 structured modules, 24 live classes — each building on the last, from
            DevOps fundamentals to a production Kubernetes deployment on AWS.
          </p>
        </div>
      </section>

      {/* ── Modules grid ── */}
      <section className="bg-slate-50 py-16 sm:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            {modules.map(({ number, title, goal, classes, icon, accent }) => (
              <div
                key={number}
                className="bg-white rounded-2xl border border-slate-200 hover:border-indigo-200 hover:shadow-lg hover:shadow-indigo-50/60 transition-all overflow-hidden flex flex-col"
              >
                {/* Accent bar */}
                <div className={`h-1 w-full bg-gradient-to-r ${accent}`} />

                <div className="p-6 flex flex-col flex-grow">
                  {/* Header */}
                  <div className="flex items-start gap-4 mb-4">
                    <div className="w-11 h-11 rounded-xl bg-slate-100 flex items-center justify-center text-xl shrink-0">
                      {icon}
                    </div>
                    <div>
                      <span className="text-slate-400 text-xs font-mono tracking-wider">
                        MODULE {number}
                      </span>
                      <h3 className="text-slate-900 font-bold text-base leading-snug">{title}</h3>
                    </div>
                  </div>

                  {/* Live classes */}
                  <div className="space-y-4 flex-grow mb-5">
                    {classes.map(({ label, topics }) => (
                      <div key={label}>
                        <p className="text-indigo-600 text-xs font-semibold uppercase tracking-wider mb-2">
                          {label}
                        </p>
                        <ul className="space-y-1.5">
                          {topics.map((t) => (
                            <li key={t} className="flex items-start gap-2 text-slate-600 text-xs leading-relaxed">
                              <span className="w-1.5 h-1.5 rounded-full bg-indigo-300 shrink-0 mt-1" />
                              {t}
                            </li>
                          ))}
                        </ul>
                      </div>
                    ))}
                  </div>

                  {/* Goal */}
                  <div className="pt-4 border-t border-slate-100">
                    <p className="text-slate-400 text-xs">
                      <span className="font-semibold text-slate-500">Goal: </span>
                      {goal}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  )
}
