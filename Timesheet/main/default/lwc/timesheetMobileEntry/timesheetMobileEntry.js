import { LightningElement, api, wire, track } from 'lwc';
import getTimesheet from '@salesforce/apex/WeeklyTimesheetController.getTimesheet';
import getProjects from '@salesforce/apex/WeeklyTimesheetController.getProjects';
import getWeeklyTimesheetItems from '@salesforce/apex/WeeklyTimesheetController.getWeeklyTimesheetItems';
import upsertLineItems from '@salesforce/apex/WeeklyTimesheetController.upsertLineItems';
import deleteTimesheetLineItems from '@salesforce/apex/WeeklyTimesheetController.deleteTimesheetLineItems';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import TIMESHEET_LINE_ITEM_OBJECT from '@salesforce/schema/Timesheet_Line_Item__c';
import ACTIVITY_CATEGORY_FIELD from '@salesforce/schema/Timesheet_Line_Item__c.Activity__c';
import ABSENCE_CATEGORY_FIELD from '@salesforce/schema/Timesheet_Line_Item__c.Absence_Category__c';

export default class TimesheetMobileEntry extends LightningElement {
    @api recordId;
    @track isLoading = true;
    @track isFormOpen = false;
    @track isSaving = false;
    
    @track timesheet;
    @track lineItems = [];
    @track selectedDate;
    
    @track projectOptions = [];
    @track activityOptions = [];
    @track absenceOptions = [];
    
    @track currentRecord = {};
    
    typeOptions = [
        { label: 'Attendance', value: 'Attendance' },
        { label: 'Absence', value: 'Absence' }
    ];

    @wire(getObjectInfo, { objectApiName: TIMESHEET_LINE_ITEM_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ACTIVITY_CATEGORY_FIELD })
    wiredActivity({ data }) {
        if (data) {
            this.activityOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: ABSENCE_CATEGORY_FIELD })
    wiredAbsence({ data }) {
        if (data) {
            this.absenceOptions = data.values.map(item => ({ label: item.label, value: item.value }));
        }
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        Promise.all([
            getTimesheet({ timesheetId: this.recordId }),
            getWeeklyTimesheetItems({ timesheetId: this.recordId })
        ]).then(results => {
            this.timesheet = results[0];
            let items = results[1] || [];
            this.lineItems = items.map(item => {
                return {
                    ...item,
                    projectName: item.Project__r ? item.Project__r.Name : 'No Project',
                    activityName: item.Type__c === 'Attendance' ? item.Activity__c : item.Absence_Category__c
                };
            });
            
            if (!this.selectedDate && this.timesheet) {
                // Ensure date parsing doesn't shift timezone negatively
                let [y, m, d] = this.timesheet.Start_Date__c.split('-');
                this.selectedDate = new Date(Date.UTC(y, m-1, d));
            }
            
            return getProjects({ empId: this.timesheet.Employee__c });
        }).then(projects => {
            this.projectOptions = projects.map(pe => ({
                label: pe.Project__r.Name,
                value: pe.Project__c,
                billable: pe.Project__r.Billable__c
            }));
            this.isLoading = false;
        }).catch(error => {
            console.error(error);
            this.showToast('Error', 'Failed to load timesheet data', 'error');
            this.isLoading = false;
        });
    }

    get timesheetName() {
        return this.timesheet ? this.timesheet.Name : 'Timesheet';
    }

    get totalHours() {
        let total = 0;
        this.lineItems.forEach(item => {
            total += (item.Duration__c || 0);
        });
        return total.toFixed(2);
    }

    get selectedDateFormatted() {
        if (!this.selectedDate) return { day: '', date: '' };
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        return {
            day: days[this.selectedDate.getUTCDay()],
            date: this.selectedDate.toISOString().split('T')[0]
        };
    }

    get filteredLineItems() {
        if (!this.selectedDate) return [];
        const dateStr = this.selectedDate.toISOString().split('T')[0];
        return this.lineItems.filter(item => item.Date__c === dateStr);
    }

    get hasItemsForSelectedDate() {
        return this.filteredLineItems.length > 0;
    }

    previousDay() {
        if (this.selectedDate) {
            let prev = new Date(this.selectedDate);
            prev.setUTCDate(prev.getUTCDate() - 1);
            let [y, m, d] = this.timesheet.Start_Date__c.split('-');
            let minDate = new Date(Date.UTC(y, m-1, d));
            if (minDate <= prev) {
                this.selectedDate = prev;
            } else {
                this.showToast('Info', 'Cannot navigate before start date.', 'info');
            }
        }
    }

    nextDay() {
        if (this.selectedDate) {
            let next = new Date(this.selectedDate);
            next.setUTCDate(next.getUTCDate() + 1);
            let [y, m, d] = this.timesheet.End_Date__c.split('-');
            let maxDate = new Date(Date.UTC(y, m-1, d));
            if (maxDate >= next) {
                this.selectedDate = next;
            } else {
                this.showToast('Info', 'Cannot navigate past end date.', 'info');
            }
        }
    }

    openNewForm() {
        this.currentRecord = {
            Timesheet__c: this.recordId,
            Date__c: this.selectedDate.toISOString().split('T')[0],
            Type__c: 'Attendance',
            Duration__c: 0,
            Employee__c: this.timesheet.Employee__c
        };
        this.isFormOpen = true;
    }

    closeForm() {
        this.isFormOpen = false;
        this.currentRecord = {};
    }

    get formTitle() {
        return this.currentRecord.Id ? 'Edit Entry' : 'New Entry';
    }

    get isAttendance() {
        return this.currentRecord.Type__c === 'Attendance';
    }

    handleInputChange(event) {
        const field = event.target.name;
        let val = event.target.value;
        if (field === 'Duration__c') {
            val = parseFloat(val);
        }
        this.currentRecord[field] = val;
    }

    saveEntry() {
        if (this.currentRecord.Type__c === 'Attendance' && (!this.currentRecord.Project__c || !this.currentRecord.Activity__c)) {
            this.showToast('Error', 'Please select Project and Activity.', 'error');
            return;
        }
        if (this.currentRecord.Type__c === 'Absence' && !this.currentRecord.Absence_Category__c) {
            this.showToast('Error', 'Please select Absence Category.', 'error');
            return;
        }
        if (!this.currentRecord.Duration__c || this.currentRecord.Duration__c <= 0) {
            this.showToast('Error', 'Please enter a valid duration.', 'error');
            return;
        }

        if (this.currentRecord.Project__c) {
            let p = this.projectOptions.find(opt => opt.value === this.currentRecord.Project__c);
            if (p) {
                this.currentRecord.Billable__c = p.billable;
            }
        }

        this.isSaving = true;
        upsertLineItems({ lineItems: [this.currentRecord] })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Entry saved.', 'success');
                    this.closeForm();
                    this.loadData();
                } else {
                    this.showToast('Error', result, 'error');
                }
                this.isSaving = false;
            })
            .catch(error => {
                this.showToast('Error', error.body?.message || 'Error saving entry.', 'error');
                this.isSaving = false;
            });
    }

    handleEdit(event) {
        const id = event.target.dataset.id;
        const item = this.lineItems.find(i => i.Id === id);
        if (item) {
            this.currentRecord = { ...item };
            this.isFormOpen = true;
        }
    }

    handleDelete(event) {
        const id = event.target.dataset.id;
        const item = this.lineItems.find(i => i.Id === id);
        if (item && confirm('Are you sure you want to delete this entry?')) {
            this.isLoading = true;
            deleteTimesheetLineItems({ lineItemIds: [item] })
                .then(result => {
                    if (result === 'Success') {
                        this.showToast('Success', 'Entry deleted.', 'success');
                        this.loadData();
                    } else {
                        this.showToast('Error', result, 'error');
                        this.isLoading = false;
                    }
                })
                .catch(error => {
                    this.showToast('Error', error.body?.message || 'Error deleting entry.', 'error');
                    this.isLoading = false;
                });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
