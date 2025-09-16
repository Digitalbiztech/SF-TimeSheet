public with sharing class EmployeeTriggerHandler {
    
    public static void checkUserDuplicationForEmployeeBeforeInsert(List<Employee__c	> employees){
        Map<Id, Employee__c> userEmployeeMap = getUserEmployeeMapForBeforeInsert(employees);
        if (userEmployeeMap.size() > 0){
            for(Employee__c	 employee : employees){
            	if(userEmployeeMap.get(employee.User__c) != null){
                	employee.User__c.addError('An Employee with same user already exists');
            	}
        	}  
        }
    }
    
    public static void checkUserDuplicationForEmployeeBeforeUpdate(List<Employee__c> employees){
        Map<Id, Employee__c> userEmployeeMap = getUserEmployeeMapForBeforeUpdate(employees);
        if (userEmployeeMap.size() > 0){
            for(Employee__c	 employee : employees){
            	if(userEmployeeMap.get(employee.User__c) != null && employee.Id != userEmployeeMap.get(employee.User__c).Id  ){
                	employee.User__c.addError('An Employee with same user already exists');
            	}
        	}
       }
    }
    
    private static Map<Id, Employee__c> getUserEmployeeMapForBeforeInsert(List<Employee__c> employees){
        Map<Id, Employee__c> userEmployeeMap = new Map<Id, Employee__c>();
        if(Employee__c.SObjectType.getDescribe().isCreateable() 
            && Schema.SObjectType.Employee__c.fields.User__c.isCreateable()) {
                userEmployeeMap = getUserEmployeeMap(employees);                                  
        } else{
            addError(employees);
        }
        return userEmployeeMap;
    }
    
    private static Map<Id, Employee__c> getUserEmployeeMapForBeforeUpdate(List<Employee__c> employees){
        Map<Id, Employee__c> userEmployeeMap = new Map<Id, Employee__c>();
        if(Employee__c.SObjectType.getDescribe().isUpdateable() 
            && Schema.SObjectType.Employee__c.fields.User__c.isUpdateable()) {
                userEmployeeMap = getUserEmployeeMap(employees);
        } else{
            addError(employees);
        }
        return userEmployeeMap;
    }

    private static Map<Id, Employee__c> getUserEmployeeMap(List<Employee__c> employees){
        Map<Id, Employee__c> userEmployeeMap = new Map<Id, Employee__c>();
        Map<Id, Employee__c> employeeMap = new Map<Id, Employee__c>([SELECT
                                                            Id,
                                                            User__c
                                                            FROM Employee__c
                                                            WHERE User__c = : getUserIds(employees)
                                                            WITH SECURITY_ENFORCED]);
        if(employeeMap != null && employeeMap.size() > 0){
            for(Id id : employeeMap.keySet()){
                userEmployeeMap.put(employeeMap.get(id).User__c, employeeMap.get(id));
            }
        }
        return userEmployeeMap;
    }

    private static List<Id> getUserIds(List<Employee__c> employees){
        List<Id> userIds = new List<Id>();
        for(Employee__c	 employee : employees){
            userIds.add(employee.User__c);
        }
        return userIds;
    }

    private static void addError(List<Employee__c> employees){
        for(Employee__c	 employee : employees){
            employee.addError('You do not have access, Please contact system admin');
        }
    }
}