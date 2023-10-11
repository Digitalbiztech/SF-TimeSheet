trigger EmployeeTrigger on Employee__c (before insert, before update) {
    
    if(Trigger.isBefore && Trigger.isInsert){
        
        EmployeeTriggerHandler.checkUserDuplicationForEmployeeBeforeInsert(Trigger.New);
        
    }else if (Trigger.isBefore && Trigger.isUpdate){
        
        EmployeeTriggerHandler.checkUserDuplicationForEmployeeBeforeUpdate(Trigger.New);
    }
}