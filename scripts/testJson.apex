Timesheet_Line_Item__c tli = [SELECT Id, Date__c, Type__c, Duration__c, Description__c FROM Timesheet_Line_Item__c LIMIT 1];
System.debug(JSON.serialize(tli));
