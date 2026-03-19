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
		
		if (count of pendingReminders) is 0 then
			return -- Nothing to do
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
		end repeat
	end tell
end run
