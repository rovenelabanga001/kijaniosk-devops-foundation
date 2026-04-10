# Question 1: What Today's Pipeline Does Not Do

To qualify as genuine CI, we would need to add the following stages:

## Property 1: Automated Verification (Build & Test)

The pipeline must prove the new code actually works and hasn't broken existing features.

Added Steps: sh 'npm install' to fetch dependencies and sh 'npm test' to run the test suite.

## Property 2: Automated Code Quality (Linting)

CI should enforce style and catch syntax errors before they reach production.

Added Steps: sh 'npm run lint' or a specific command like sh 'eslint .' to check for code smells.

## Property 3: Immediate Feedback

Missing Step: The current post block only logs "SUCCESS" to the console. If a dev pushes code and walks away, they won't know it failed until they manually check the Jenkins UI.

Implementation: You must automate the notification loop.

```
Groovy
post {
failure {
// Commands for immediate alert
sh 'curl -X POST -H "Content-type: application/json" --data \'{"text":"Build Failed: Check Jenkins for details!"}\' [SLACK_WEBHOOK_URL]'
mail to: 'team@example.com', subject: 'Build Failed', body: 'The latest build broke the main branch.'
}
}
```

# Question 2: The Broken-Build Contract in Practice

## The Scenario:

A developer on the KijaniKiosk team is rushing to finish a feature for the board review. They push code that breaks the build, but argue, "I need to keep working on the UI because the board review is more important than the failing unit tests right now. I'll fix the build tomorrow."

## The Hidden Cost:

This exception is costly because the Main Branch is the single source of truth. When it is broken:

Work Stops: No other developer can safely pull the latest changes. If they do, they are now working on top of broken code, making it impossible to tell if their new work is buggy or if they just inherited the existing break.

Compounding Debt: If "just this once" happens on Monday, and another dev pushes on Tuesday, you now have a "Multiple Head Trauma" build where two or three different issues are tangled together. By the end of a two-week sprint,
the team often spends the final 48 hours in "Integration Hell," manually untangling code instead of preparing for the board review.

# Question 3: The Jenkinsfile in the Repository

Storing the pipeline in the UI (often called "Click-Ops") creates two major problems:

- **Lack of Version Control & Peer Review:** If the pipeline lives in the UI, a developer can change a build step without anyone else knowing. There is no "Pull Request" for a UI change. If a build starts failing because a configuration was changed, there is no git log to see who changed it or why.

- **Disaster Recovery (Bus Factor):** If the Jenkins server crashes or the volume is wiped, every single pipeline configuration is lost. With a Jenkinsfile, you simply create a new Jenkins instance, point it at the repository, and your entire CI/CD logic is restored instantly.

The repository becomes the "Backup" for your automation logic.

# Question 4: Webhooks vs Polling

## Technical Mechanism (Webhook):

A **Webhook** is a "Push" mechanism. You configure GitHub/GitLab with your Jenkins URL. The moment a developer runs git push, the Git server sends an HTTP POST request to Jenkins saying, "Hey, something changed!" Jenkins triggers the build immediately.

## When the other is appropriate:

**SCM Polling**(the "Pull" mechanism) is better when your Jenkins server is behind a strict firewall that doesn't allow incoming connections from the internet (preventing GitHub from "talking" to it), or when using a legacy version control system that doesn't support webhooks.

## The Trade-off:

For a team of 20 developers pushing multiple times a day, polling becomes a concern at intervals shorter than 2–5 minutes.

- High Load: If 20 people push frequently and Jenkins polls every 60 seconds, the Git API may rate-limit the server.

- Latency: If you poll every 15 minutes to save resources, a developer has to wait up to 15 minutes just to see if their 10-second test passed, destroying the "Fast Feedback" loop of CI.
