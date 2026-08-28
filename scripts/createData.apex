List<Employee__c> newEmployees = new List<Employee__c>();
for (Integer i = 0; i < 3; i++) {
    Employee__c emp = new Employee__c(
        Name = 'Test Employee ' + Math.abs(Crypto.getRandomInteger()),
        First_Name__c = 'Test',
        Last_Name__c = 'Employee ' + i,
        Active__c = true
    );
    newEmployees.add(emp);
}
insert newEmployees;

List<Project__c> projects = [SELECT Id FROM Project__c WHERE Active__c = true LIMIT 3];
while (projects.size() < 3) {
    Project__c p = new Project__c(Name='Test Project ' + projects.size(), Active__c=true, Start_Date__c=Date.today().addDays(-100), Billable__c='Yes');
    insert p;
    projects.add(p);
}

List<Timesheet__c> timesheets = new List<Timesheet__c>();

// 5 timesheets for 5 consecutive weeks.
Date startDate = Date.today().toStartOfWeek().addDays(1).addDays(-35); 

for(Employee__c emp : newEmployees) {
    for(Integer i=0; i<5; i++) {
        Timesheet__c ts = new Timesheet__c(
            Name = 'TS-W' + i,
            Employee__c = emp.Id,
            Start_Date__c = startDate.addDays(i * 7),
            End_Date__c = startDate.addDays(i * 7 + 6),
            Status__c = 'Submitted',
            Manager__c = UserInfo.getUserId()
        );
        timesheets.add(ts);
    }
}
insert timesheets;

List<Timesheet_Line_Item__c> lineItems = new List<Timesheet_Line_Item__c>();
for(Timesheet__c ts : timesheets) {
    for(Integer day=0; day<7; day++) { // Monday to Sunday
        Date currentDate = ts.Start_Date__c.addDays(day);
        
        // 3 projects per day
        for(Project__c p : projects) {
            Timesheet_Line_Item__c tli = new Timesheet_Line_Item__c(
                Timesheet__c = ts.Id,
                Project__c = p.Id,
                Date__c = currentDate,
                Duration__c = 2, 
                Type__c = 'Attendance',
                Activity__c = 'Development-Coding',
                Billable__c = 'Yes',
                Description__c = 'Test data'
            );
            lineItems.add(tli);
        }
    }
}
insert lineItems;

System.debug('Success: Created ' + newEmployees.size() + ' employees, ' + timesheets.size() + ' timesheets, and ' + lineItems.size() + ' line items.');
