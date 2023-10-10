public with sharing class TimsheetController {
    Map<Id, Timesheet__c> piwiTimesheetMap = new Map<Id, Timesheet__c>();
    Map<Id, Timesheet__c> timesheetMap = new Map<Id, Timesheet__c>();
    Map<Id, ProcessInstance> processInstanceMap = new Map<Id, ProcessInstance>();

    @AuraEnabled(cacheable=true)
    public static Map<Id, Timesheet__c> getProcessInstanceWorkItem(Id userID){
        if(Timesheet__c.SObjectType.getDescribe().isAccessible() 
            && Schema.SObjectType.Timesheet__c.fields.Id.isAccessible() 
            && Schema.SObjectType.Timesheet__c.fields.Name.isAccessible()
            && Employee__c.SObjectType.getDescribe().isAccessible() 
            && Schema.SObjectType.Employee__c.fields.Name.isAccessible()){
                timesheetMap = new Map<Id, Timesheet__c>([SELECT
                                                            Id,
                                                            Name,
                                                            Employee__r.Name
                                                            FROM Timesheet__c
                                                            WHERE Status__c = 'Submitted'
                                                            WITH SECURITY_ENFORCED
                ]);
                List<Id> timesheetIds = new List<Id>();
                for(Id key : timesheetMap.keySet()){
                    timesheetIds.add(timesheetMap.get(key).Id);
                }
                processInstanceMap = getProcessInstance(timesheetIds);
                List<Id> processInstanceIds = new List<Id>();
                for (ProcessInstance processInstanceRecord : processInstanceRecords) {
                    processInstancesMap.put(processInstanceRecord.TargetObjectId, processInstanceRecord);
                    processInstanceIds.add(processInstanceRecord.Id);
                }
                Map<Id, ProcessInstanceWorkitem> processInstanceWorkitemsMap = getProcessInstanceWorkitemsMap(processInstanceIds, userID);
                
        } else{
            String errorMessage = 'You do not have access, please contact System Admin';
            AuraHandledException ae = new AuraHandledException(errorMessage);
            ae.setMessage(errorMessage);
            throw ae;
        }
        return piwiTimesheetMap;
    }

    private static Map<Id, ProcessInstance> getProcessInstance(List<Id> timesheetIds){
        processInstanceMap = new Map<Id, ProcessInstance>([SELECT 
                                                                Id,
                                                                TargetObjectId
                                                                FROM ProcessInstance 
                                                                WHERE Status = 'Pending' AND TargetObjectId =:timesheetIds
                                                                WITH SECURITY_ENFORCED
        ]); 
        return processInstanceMap;
    }

    private static Map<Id, ProcessInstanceWorkitem> getProcessInstanceWorkitemsMap(List<Id> processInstanceIds, Id userID){
        List<ProcessInstanceWorkitem> processInstanceWorkItems = new List<ProcessInstanceWorkitem>();
        processInstanceWorkItems = [
                                    SELECT
                                    Id,
                                    ActorId,
                                    OriginalActorId,
                                    ProcessInstanceId
                                    FROM ProcessInstanceWorkitem
                                    WHERE OriginalActorId = :userID AND ProcessInstanceId =:processInstanceIds
                                    WITH SECURITY_ENFORCED
        ];
        for (ProcessInstanceWorkitem processInstanceWorkitem : processInstanceWorkItems) {
            Id timesheetid = processInstanceMap.get(processInstanceWorkitem.ProcessInstanceId).TargetObjectId;
            Timesheet__c timesheet = timesheetMap.get(timesheetid);
            piwiTimesheetMap.put(processInstanceWorkitem.Id, timesheet);
        }
    }
}