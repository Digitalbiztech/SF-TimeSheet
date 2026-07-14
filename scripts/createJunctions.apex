List<Employee__c> emps = [SELECT Id FROM Employee__c WHERE Name LIKE 'Subordinate%'];
List<Project__c> projects = [SELECT Id FROM Project__c WHERE Active__c = true LIMIT 3];

List<Project_Employee__c> peList = new List<Project_Employee__c>();
for (Employee__c emp : emps) {
    for (Project__c proj : projects) {
        peList.add(new Project_Employee__c(
            Employee__c = emp.Id,
            Project__c = proj.Id
        ));
    }
}
insert peList;
System.debug('Created ' + peList.size() + ' Project_Employee__c records.');
