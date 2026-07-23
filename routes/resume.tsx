import type { ComponentChildren } from "preact";
import { PageMeta } from "@/components/PageMeta.tsx";
import PrintButton from "@/islands/PrintButton.tsx";
import { define } from "@/utils.ts";

function RoleDetail({ children }: { children: ComponentChildren }) {
  return (
    <details class="role-detail screen-only">
      <summary>The story</summary>
      <div>{children}</div>
    </details>
  );
}

export default define.page(function Resume() {
  return (
    <>
      <PageMeta
        title="Resume"
        description="Devon Wells, principal software engineer."
        path="/resume"
      />
      <article class="resume">
        <div class="screen-only resume-actions">
          <PrintButton />
        </div>
        <header class="resume-header">
          <h1>Devon Wells</h1>
          <p class="resume-title">Principal Frontend Engineer</p>
          <p class="resume-contact">
            <a href="mailto:dev@wlls.dev">dev@wlls.dev</a>
            <span aria-hidden="true">/</span>
            <a href="https://github.com/devdumpling">
              <span class="screen-only">GitHub</span>
              <span class="print-only">github.com/devdumpling</span>
            </a>
            <span aria-hidden="true">/</span>
            <a href="https://www.linkedin.com/in/devon-a-wells/">
              <span class="screen-only">LinkedIn</span>
              <span class="print-only">linkedin.com/in/devon-a-wells</span>
            </a>
          </p>
        </header>

        <section class="resume-section">
          <h2>Experience</h2>

          <div class="experience-item">
            <div class="experience-heading">
              <h3>Judi Health (Capital Rx) / Amino Health</h3>
              <span>Feb 2025 - Present</span>
            </div>
            <p class="role">Principal Software Engineer</p>
            <ul>
              <li>
                Led ground-up frontend rebuild from legacy Flask/React 16 to Next.js 15, React 19,
                Tailwind 4, and shadcn
              </li>
              <li>
                Reduced JS payload from multiple megabytes to &lt;500KB, eliminating slow page load
                on marginal devices
              </li>
              <li>
                Established full test coverage across user journeys with Vitest, Playwright,
                Turborepo, and pnpm, cutting CI feedback from hours to minutes
              </li>
              <li>Architected BFF layer enabling a thin client while keeping services decoupled</li>
              <li>
                Post-acquisition: leading frontend unification across Judi Care consumer products
                serving 54M+ plan members
              </li>
            </ul>
            <RoleDetail>
              <p>
                Joined Amino Health, a healthtech startup focused on care navigation, to lead a
                complete frontend rebuild and redesign. The legacy stack was a Flask/Django backend
                serving client-side React 16, so every page load meant downloading megabytes of
                JavaScript before anything rendered.
              </p>
              <p>
                Within months, Capital Rx acquired Amino. Scope expanded from rebuilding one app to
                unifying frontend across all consumer-facing products under the Judi Care brand.
              </p>
            </RoleDetail>
          </div>

          <div class="experience-item">
            <div class="experience-heading">
              <h3>GoodRx</h3>
              <span>Jan 2022 - Feb 2025</span>
            </div>
            <p class="role">
              Principal Software Engineer <span>2024 - 2025</span>
            </p>
            <ul>
              <li>Rebuilt a legacy Next.js 11/Express frontend as Next.js 13 and React 18</li>
              <li>Designed a new Tailwind and shadcn-based design system</li>
              <li>
                Led migration of 1M+ lines of coupled legacy components into a modern monorepo
              </li>
              <li>
                Created the <code>sing</code> CLI for orchestrating common frontend tasks
              </li>
              <li>Built a documentation platform that transformed company knowledge culture</li>
              <li>Led the core pricing funnel rebuild across three previously siloed teams</li>
              <li>Led and organized the Frontend Guild community of practice</li>
            </ul>

            <p class="role">
              Engineering Manager <span>2023, nine months</span>
            </p>
            <ul>
              <li>
                Managed the Application Platform Frontend team while contributing architecture
              </li>
              <li>Deliberately returned to the IC path to focus on hands-on craft</li>
            </ul>

            <p class="role">
              Lead (Staff) Software Engineer <span>2022 - 2023</span>
            </p>
            <ul>
              <li>Removed 2M+ lines of dead code, cutting build times by more than ten minutes</li>
              <li>
                Moved CI from Lerna to Turborepo and pnpm, reducing two-hour pipelines to 15 minutes
              </li>
              <li>Restructured the monorepo for decoupled contributions</li>
              <li>Transformed the team's reputation from gatekeepers to trusted partners</li>
              <li>Hosted an internal engineering podcast to foster knowledge sharing</li>
            </ul>
            <RoleDetail>
              <p>
                Joined to own a small CMS and lead a Design System team. Scope expanded as I fixed
                long-standing pain points: dead code slowing builds, CI pipelines that took hours,
                and a tangled monolith that made teams step on each other.
              </p>
              <p>
                The trust built across teams led naturally to management. After nine months I chose
                to return to IC work and focus on a platform that amplified every frontend engineer
                through tooling, documentation, and infrastructure.
              </p>
            </RoleDetail>
          </div>

          <div class="experience-item">
            <div class="experience-heading">
              <h3>Everything But The House</h3>
              <span>Mar 2021 - Dec 2021</span>
            </div>
            <p class="role">Senior Software Engineer / Frontend Team Lead</p>
            <ul>
              <li>Built a React and Next.js e-commerce platform for estate sales</li>
              <li>Implemented an accessible design system and typed utility libraries</li>
            </ul>
          </div>

          <div class="experience-item condensed">
            <div class="experience-heading">
              <h3>American Electric Power</h3>
              <span>Dec 2019 - Mar 2021</span>
            </div>
            <p class="role">Software Developer</p>
            <p>
              Modernized legacy applications with Lit and Polymer 3. Delivered Oracle Data Analytics
              Cloud solutions, PHP widgets, and REST APIs.
            </p>
          </div>

          <div class="experience-item condensed">
            <div class="experience-heading">
              <h3>Maydm</h3>
              <span>Aug 2016 - Nov 2019</span>
            </div>
            <p class="role">Technology Coordinator / Project Manager</p>
            <p>
              One of three employees at a STEM education nonprofit. Built a CS teaching platform
              serving 700+ students and led operations and technical direction.
            </p>
          </div>

          <div class="experience-item condensed">
            <div class="experience-heading">
              <h3>Freelance Web Development</h3>
              <span>2010 - 2015</span>
            </div>
          </div>
        </section>

        <section class="resume-section education">
          <h2>Education</h2>
          <p>
            <strong>Oberlin College</strong> - Bachelor of Arts, Computer Science, 2015
          </p>
        </section>

        <section class="resume-section toolkit">
          <h2>Toolkit</h2>
          <dl>
            <div>
              <dt>Languages</dt>
              <dd>TypeScript, HTML, CSS, Python, Gleam, Rust, SQL</dd>
            </div>
            <div>
              <dt>Frameworks</dt>
              <dd>Svelte, React, Next.js, TanStack, Astro</dd>
            </div>
            <div>
              <dt>Runtimes</dt>
              <dd>Deno, Bun, Node</dd>
            </div>
            <div>
              <dt>Tooling</dt>
              <dd>Turborepo, pnpm, Playwright, Vite, Figma</dd>
            </div>
            <div>
              <dt>Data</dt>
              <dd>Postgres, SQLite, Zero</dd>
            </div>
            <div>
              <dt>Platforms</dt>
              <dd>AWS, GCP, Cloudflare</dd>
            </div>
          </dl>
        </section>

        <section class="resume-section projects screen-only">
          <h2>Selected Projects</h2>
          <div class="project-list">
            <article>
              <h3>
                <a href="https://github.com/devdumpling/snowglobe">Snowglobe</a>
              </h3>
              <p>
                Interactive year-in-review experience with realtime presence and a Gleam backend.
              </p>
            </article>
            <article>
              <h3>
                <a href="https://github.com/devdumpling/beacon">Beacon</a>
              </h3>
              <p>Privacy-focused healthcare analytics with a sub-1KB web worker client.</p>
            </article>
            <article>
              <h3>
                <a href="https://github.com/wellwright-labs/pulse">Pulse</a>
              </h3>
              <p>Deno CLI for running and recording structured workflow experiments.</p>
            </article>
            <article>
              <h3>
                <a href="https://github.com/devdumpling/wlls">wlls.dev</a>
              </h3>
              <p>This site: a Deno and Fresh home for writing and web experiments.</p>
            </article>
          </div>
        </section>
      </article>
    </>
  );
});
