-- reminders_to_things.applescript
-- Migrates incomplete items from the Reminders Inbox to Things 3 Inbox
-- Preserves due date/time if present, then marks the Reminder as complete
-- Designed to be run on a schedule via launchd

on run
	tell application "Reminders"
		-- Target the Reminders Inbox list
		-- Default Siri inbox is named "INBOX" (all caps) — verify with:
		-- tell application "Reminders" to get name of every list of default account
		set inboxList to list "INBOX" of default account
		
		-- Get all incomplete reminders
		set pendingReminders to (reminders in inboxList whose completed is false)
		set pendingCount to count of pendingReminders
		set migratedCount to 0
		
		if pendingCount is 0 then
			return "pendingBeforeRun=0" & linefeed & "pendingAfterRun=0" & linefeed & "migratedCount=0"
		end if
		
		repeat with theReminder in pendingReminders
			set reminderName to name of theReminder

			-- Safely read optional properties (may be missing value or throw)
			set reminderBody to missing value
			try
				set reminderBody to body of theReminder
			end try

			set reminderDueDate to missing value
			try
				set reminderDueDate to due date of theReminder
			end try

			-- Build the Things to-do via AppleScript
			tell application "Things3"
				set newToDo to make new to do with properties {name:reminderName, tag names:"siri"}

				-- Add notes/body if present
				if reminderBody is not missing value and reminderBody is not "" then
					set notes of newToDo to reminderBody
				end if

				-- Add due date if present
				if reminderDueDate is not missing value then
					set due date of newToDo to reminderDueDate
				end if
			end tell

			-- Mark the Reminder as complete so it doesn't get picked up again
			set completed of theReminder to true
			set migratedCount to migratedCount + 1
		end repeat

		set remainingCount to count of (reminders in inboxList whose completed is false)
		return "pendingBeforeRun=" & pendingCount & linefeed & "pendingAfterRun=" & remainingCount & linefeed & "migratedCount=" & migratedCount
	end tell
end run
