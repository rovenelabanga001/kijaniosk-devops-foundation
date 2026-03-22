### How flow, feedback and learning will appear in our workflow

## Flow

- **Flow** is is about accelerating the journey from a developer’s keyboard to the production environment through the delivery pipeline.Below is are measures will
  adhere to:

1. **Standardised stack**: By choosing the appropriate tech stack and using mature frameworks that provide clear "lanes" for development, reducing architectural indecision
2. **Version control strategy**: We use simplified gitflow. Developers work on dev branch, and code only moves to main branch via pull requests, making it easy to track changes and avoid merge conflicts
3. **Continous integration**: Everytime we push code to github, automated scripts should validate code immediately

## Feedback

- **Feedback** is about shortening and amplifying look-back loops so we can fix quality issues early, rather than at the end of the month.
  Below is how we will achieve that in our workflow

1. **Automated Testing**: We move from manual checks to automated unit tests in our backend. If a change in the payment logic breaks a report, the system tells the developer in minutes, not days.

2. **Security Guardrails**: Our IAM Policies act as immediate feedback. If a service tries to perform an unauthorized action (like writing to a read-only bucket), the system denies it and logs the attempt, alerting us to a potential misconfiguration or breach.

3. **Logging & Monitoring**: Adding debug logs for payment statuses ensures that when a transaction fails, the "right" side of the loop (production) sends clear data back to the "left" side (development).

## Learning

**Learning** is about creating a culture of experimentation and taking risks, improving the system from recent failures. These are the measures we will take

1. **Infrastructure as Code (IaC)**: By documenting our S3 buckets and IAM roles in code, the team can "replay" the environment setup. If someone discovers a better way to segment the network, we update the code and everyone learns from it.

2. **Blame-Free Post-Mortems**: When we hit an Error, we don't just fix it—we document the solution so the next engineer doesn't repeat the struggle.

3. **Cross-Skilling**: Switching between stacks encourages the team to learn different mental models of software architecture, making the whole engineering organization more versatile.
