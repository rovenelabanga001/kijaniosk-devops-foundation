# KijaniKiosk — Board Demonstration Script
**Event:** Monday follow-up board meeting  
**Presenter:** Nia (spoken lines) + Amina (operates the pipeline)  
**Rollback time on record:** 33 seconds (from rollback-evidence.txt, T0 18:10:20 → T2 18:10:53)

---

*[Amina opens two terminal windows on the shared screen. The left shows the health monitor. The right is ready for commands.]*

**Nia:**
Thank you all for your time this morning. What you are about to see is our system handling a deployment failure on its own — no phone calls, no engineers scrambling, no one manually pressing a button to fix it.

---

*[Amina runs the health monitor in the left terminal. Green check marks begin appearing every five seconds.]*

**Nia:**
On the left, you can see our system checking itself every five seconds — confirming that payments are being processed correctly. This is running continuously in the background at all times.

---

*[Amina runs the deployment command in the right terminal. The new version deploys to the idle environment. Amina switches traffic to the new version.]*

**Nia:**
Amina has just published an update to our payments service and moved all customer traffic onto it. At this moment, every payment request is being handled by the new version. The monitor on the left is watching it closely.

---

*[Amina stops the green service, simulating a critical fault in the new version. The monitor begins showing warnings.]*

**Nia:**
The new version has just developed a critical fault — the kind that would have caused payment failures for our customers. You can see the warnings appearing on the left. Our system has detected the problem. No one has done anything yet. We are watching it respond on its own.

---

*[The monitor fires the rollback automatically. The right terminal shows the system switching back to the previous version. The left terminal confirms recovery.]*

**Nia:**
The system just fixed itself. It detected three consecutive failures, decided the new version was unsafe, and switched all customer traffic back to the previous stable version — automatically, with no human involvement. From the moment the fault appeared to the moment customers were back on a healthy service: **33 seconds**.

---

*[Amina displays the post-rollback health check confirming the previous version is serving.]*

**Nia:**
At fifty thousand transactions per hour, thirty-three seconds represents fewer than five hundred payment requests exposed to the fault window — and those requests are retried automatically. In the old process, a fault like this would have required an engineer to notice, diagnose, and manually intervene. That process took four minutes on a good day. The difference between four minutes and thirty-three seconds, at our transaction volume, is the difference between an inconvenience and a headline.

That is what we have built. I am happy to take questions.

---

*[End of demonstration. Amina closes the terminals.]*

---

**Word count (spoken sections only):** 247 words  
**Technical acronyms in spoken sections:** None  
**Narrative beats:** Introduce → Deploy → Switch → Fault → Rollback → Business value  
**Rollback time:** 33 seconds — matches rollback-evidence.txt exactly (T0 18:10:20 → T2 18:10:53)