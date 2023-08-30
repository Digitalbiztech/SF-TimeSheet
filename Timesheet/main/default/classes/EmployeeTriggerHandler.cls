public with sharing class EmployeeTriggerHandler {
    
   public static void checkUserDuplicationForEmployeeBeforeInsert(List<Employee__c	> employees){
       List<Id> userIds = new List<Id>();
       for(Employee__c	 employee : employees){
           userIds.add(employee.User__c);
       }
       Map<Id, Employee__c> employeeMap = new Map<Id, Employee__c	>();
       try{
           if(Employee__c.SObjectType.getDescribe().isAccessible() &&
              Schema.SObjectType.Employee__c.fields.Id.isAccessible() &&
              Schema.SObjectType.Employee__c.fields.User__c.isAccessible()) {
                  employeeMap = new Map<Id, Employee__c	>([SELECT
                                                           Id, 
                                                           User__c 
                                                           FROM Employee__c	 
                                                           WHERE User__c = : userIds 
                                                           WITH SECURITY_ENFORCED]);
       	   }
       }catch(Exception e){
           System.debug('The exception is : ' + e.getMessage());
           throw new AuraHandledException('Unexpected Error, contact System Admin');
       }
       Map<Id, Employee__c> userEmployeeMap = new Map<Id, Employee__c>();
       for(Id id : employeeMap.keySet()){
           userEmployeeMap.put(employeeMap.get(id).User__c, employeeMap.get(id));
       }
       if (employeeMap.size() > 0){
           for(Employee__c	 employee : employees){
            	if(userEmployeeMap.get(employee.User__c) != null){
                	employee.User__c.addError('An Employee with same user already exists');
            	}
        	}  
       }
    }
    
    public static void checkUserDuplicationForEmployeeBeforeUpdate(List<Employee__c> employees){
        
        List<Id> userIds = new List<Id>();
        for(Employee__c	 employee : employees){
            userIds.add(employee.User__c);
        }
        Map<Id, Employee__c	> employeeMap = new Map<Id, Employee__c	>();
        try{
            if(Employee__c.SObjectType.getDescribe().isAccessible() &&
               Schema.SObjectType.Employee__c.fields.Id.isAccessible() &&
               Schema.SObjectType.Employee__c.fields.User__c.isAccessible()) {
                   employeeMap = new Map<Id, Employee__c	>([SELECT
                                                           Id, 
                                                           User__c 
                                                           FROM Employee__c	 
                                                           WHERE User__c = : userIds 
                                                           WITH SECURITY_ENFORCED]);
            }
        }catch(Exception e){
            System.debug('The exception is : ' + e.getMessage());
            throw new AuraHandledException('Unexpected Error, contact System Admin');
        }
        Map<Id, Employee__c	> userEmployeeMap = new Map<Id, Employee__c	>();
        for(Id id : employeeMap.keySet()){
            userEmployeeMap.put(employeeMap.get(id).User__c, employeeMap.get(id));
        }
        if (employeeMap.size() > 0){
            for(Employee__c	 employee : employees){
            	if(employee.Id != userEmployeeMap.get(employee.User__c).Id && userEmployeeMap.get(employee.User__c) != null){
                	employee.User__c.addError('An Employee with same user already exists');
            	}
        	}
       }
    }
}