Id managerUserId = '005DZ00000AsWVmYAN';



List<Timesheet__c> tsList = [SELECT Id FROM Timesheet__c WHERE Employee__r.Name LIKE 'Test Employee%' OR Employee__c = 'a01DZ00000JIIvlYAH'];
for(Timesheet__c ts : tsList) {
    ts.Manager__c = managerUserId;
}
update tsList;
System.debug('Updated ' + tsList.size() + ' timesheets to manager ' + managerUserId);
