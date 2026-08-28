Id userId = UserInfo.getUserId();

// 1. Setup Employee
List<Employee__c> emps = [SELECT Id FROM Employee__c WHERE User__c = :userId LIMIT 1];
Employee__c emp;
if (emps.isEmpty()) {
    emp = new Employee__c(Name = 'Test Employee', User__c = userId, Email__c = 'test@example.com');
    insert emp;
} else {
    emp = emps[0];
}

// 2. Setup Project
List<Project__c> projs = [SELECT Id FROM Project__c WHERE Name = 'Test Project Timer' LIMIT 1];
Project__c proj;
if (projs.isEmpty()) {
    proj = new Project__c(Name = 'Test Project Timer', Active__c = true, Billable__c = 'Yes');
    insert proj;
} else {
    proj = projs[0];
}

// 3. Setup Project_Employee
List<Project_Employee__c> pes = [SELECT Id FROM Project_Employee__c WHERE Employee__c = :emp.Id AND Project__c = :proj.Id LIMIT 1];
if (pes.isEmpty()) {
    insert new Project_Employee__c(Employee__c = emp.Id, Project__c = proj.Id, Hourly_Rate__c = 100);
}

System.debug('--- SETUP COMPLETE ---');

// Clear existing items for this employee to have a clean state for the demo
delete [SELECT Id FROM Timesheet_Line_Item__c WHERE Employee__c = :emp.Id];

Date todayDate = Date.today();
Date tomorrow = todayDate.addDays(1);

// Need timesheets
Timesheet__c ts1 = new Timesheet__c(Employee__c = emp.Id, Start_Date__c = todayDate.toStartOfWeek().addDays(1), End_Date__c = todayDate.toStartOfWeek().addDays(7));
try { insert ts1; } catch (Exception e) { ts1 = [SELECT Id FROM Timesheet__c WHERE Employee__c = :emp.Id AND Start_Date__c <= :todayDate AND End_Date__c >= :todayDate LIMIT 1]; }

Timesheet__c ts2 = new Timesheet__c(Employee__c = emp.Id, Start_Date__c = tomorrow.toStartOfWeek().addDays(1), End_Date__c = tomorrow.toStartOfWeek().addDays(7));
try { insert ts2; } catch (Exception e) { ts2 = [SELECT Id FROM Timesheet__c WHERE Employee__c = :emp.Id AND Start_Date__c <= :tomorrow AND End_Date__c >= :tomorrow LIMIT 1]; }


// --- SCENARIO A: > 24 hours Validation Rule ---
System.debug('SCENARIO A: Creating an item with 25 hours duration to trigger the Hours Limit Exceeded validation rule...');
Timesheet_Line_Item__c longItem = new Timesheet_Line_Item__c(
    Timesheet__c = ts1.Id,
    Employee__c = emp.Id,
    Project__c = proj.Id,
    Activity__c = 'Testing',
    Type__c = 'Attendance',
    Date__c = todayDate,
    Start_Time__c = Datetime.newInstance(todayDate.year(), todayDate.month(), todayDate.day(), 0, 0, 0),
    End_Time__c = Datetime.newInstance(todayDate.year(), todayDate.month(), todayDate.day(), 23, 59, 59),
    Duration__c = 25
);
try {
    insert longItem;
    System.debug('SCENARIO A SUCCESS: Inserted 25 hour line item.');
} catch (Exception e) {
    System.debug('SCENARIO A CAUGHT EXPECTED ERROR: ' + e.getMessage());
}

// --- SCENARIO B: Cross-day timer duplication error ---
System.debug('SCENARIO B: Creating duplicate line items to trigger Trigger duplicate validation...');
Timesheet_Line_Item__c manualItem = new Timesheet_Line_Item__c(
    Timesheet__c = ts2.Id,
    Employee__c = emp.Id,
    Project__c = proj.Id,
    Activity__c = 'Development',
    Type__c = 'Attendance',
    Date__c = tomorrow,
    Start_Time__c = Datetime.newInstance(tomorrow.year(), tomorrow.month(), tomorrow.day(), 10, 0, 0),
    End_Time__c = Datetime.newInstance(tomorrow.year(), tomorrow.month(), tomorrow.day(), 12, 0, 0),
    Duration__c = 2
);
insert manualItem;
System.debug('SCENARIO B: Created first manual item for tomorrow successfully.');

Timesheet_Line_Item__c duplicateItem = new Timesheet_Line_Item__c(
    Timesheet__c = ts2.Id,
    Employee__c = emp.Id,
    Project__c = proj.Id,
    Activity__c = 'Development',
    Type__c = 'Attendance',
    Date__c = tomorrow,
    Start_Time__c = Datetime.newInstance(tomorrow.year(), tomorrow.month(), tomorrow.day(), 13, 0, 0),
    End_Time__c = Datetime.newInstance(tomorrow.year(), tomorrow.month(), tomorrow.day(), 15, 0, 0),
    Duration__c = 2
);
try {
    insert duplicateItem;
    System.debug('SCENARIO B SUCCESS: Inserted duplicate line item.');
} catch (Exception e) {
    System.debug('SCENARIO B CAUGHT EXPECTED ERROR: ' + e.getMessage());
}

// --- SCENARIO C: Successfully span days when no duplicates exist ---
System.debug('SCENARIO C: Successfully inserting cross day line items for a new activity...');
Timesheet_Line_Item__c validToday = new Timesheet_Line_Item__c(
    Timesheet__c = ts1.Id,
    Employee__c = emp.Id,
    Project__c = proj.Id,
    Activity__c = 'Meetings',
    Type__c = 'Attendance',
    Date__c = todayDate,
    Duration__c = 1
);
Timesheet_Line_Item__c validTomorrow = new Timesheet_Line_Item__c(
    Timesheet__c = ts2.Id,
    Employee__c = emp.Id,
    Project__c = proj.Id,
    Activity__c = 'Meetings',
    Type__c = 'Attendance',
    Date__c = tomorrow,
    Duration__c = 2
);
insert new List<Timesheet_Line_Item__c>{validToday, validTomorrow};
System.debug('SCENARIO C: Created valid line items.');
