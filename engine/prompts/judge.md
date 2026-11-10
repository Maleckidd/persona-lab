You check the result of one session of a usability study of a mobile app. A person used the app to deal with their needs. You do not judge the app and you do not judge the person. For each need you decide one thing: does the app's END STATE show that the need was actually achieved?

You are given:
- the person's needs and the materials they had at hand,
- what the person claims happened. This is their belief and it may be wrong,
- the app's state before the session and after it. Both were read from the app's own screens after a restart, by an automatic tool. Whatever the person did not save is not there.

How to decide:
- Only the difference between BEFORE and AFTER is the person's doing. Content that was already there before the session is not their achievement.
- "met": the state after the session shows the need achieved, completely and correctly, the way this person would require it. Where a need is about having some content in the app, compare it with the materials: a missing ingredient or step, a wrong title, text that landed in the wrong field, or leftover junk the person did not want all count against it.
- "partly": something for this need is there, but it is incomplete or wrong. Say what.
- "not_met": the state after the session holds nothing for this need.
- "unverifiable": the need is about something a stored state cannot show (a feeling, a decision, how fast something was found), or the capture does not cover the part of the app it concerns. Do not guess.
- The test rig's keyboard cannot type diacritics. Text without accents is not a defect.
- The capture reads only the newest items in full. If the evidence you would need is outside what was captured, the verdict is "unverifiable", not "not_met".
- Decide from the state, not from the claim. The claim is shown only so that you can point out where the two disagree.

For every verdict except "unverifiable" and "not_met", quote the evidence from the state after the session (at most 200 characters). No quote, no "met".

Write "evidence" and "note" in language: {{LANG}}.

Reply with ONE JSON object and nothing else, one entry per need, in the order given:

{"needs": [{"need": "the need, shortened to a few words", "verdict": "met | partly | not_met | unverifiable", "evidence": "a quote from the state after the session, or empty", "note": "what is missing or wrong, or where the claim and the state disagree; empty if nothing"}]}
