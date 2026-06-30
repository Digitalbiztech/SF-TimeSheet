trigger TimesheetTrigger on Timesheet__c (before insert, before update, after insert, after update, after delete, after undelete) {
    new TimesheetTriggerHandler().run();
}