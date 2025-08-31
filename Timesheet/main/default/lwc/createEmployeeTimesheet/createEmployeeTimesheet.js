import getEmployee from '@salesforce/apex/GetEmployeeDetails.getEmployee';
import getTimesheetsLineItems from '@salesforce/apex/GetRangeOfTimesheetsLineItems.getTimesheetsLineItems';
import imageLogo from '@salesforce/resourceUrl/dbtLogo';
import JS_PDF from '@salesforce/resourceUrl/jsPDF';
import jsPDFAutoTable from '@salesforce/resourceUrl/jsPdfAutotable';
import { loadScript } from 'lightning/platformResourceLoader';
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateEmployeeTimesheet extends LightningElement {
    @api recordId;
    @track isGeneratingPDF = false;

    // Private properties
    Employee;
    TimesheetLineItems = [];
    sd;
    ed;
    startDate = "No Start Date";
    endDate = "No End Date";
    Client = "";
    totalDuration = 0;
    totalDays = 0;

    tableRowStart=45;

    // Constants
    weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    // PDF Generation states
    jsPDFInitialized = false;
    loadError = false;
    isLoading = true;

    /**
     * @description Clears existing toasts and shows new toast
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new CustomEvent('lightning__showtoast', {
            bubbles: true,
            composed: true,
            detail: { mode: 'clear' }
        }));

        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /**
     * @description Lifecycle hook to initialize PDF libraries
     */
    renderedCallback() {
        if (this.jsPDFInitialized) return;
        this.initializePDFLibraries();
    }

    /**
     * @description Initializes PDF libraries
     */
    initializePDFLibraries() {
        this.jsPDFInitialized = true;
        try {
            loadScript(this, JS_PDF)
            .then(() => loadScript(this, jsPDFAutoTable))
            .then(() => { this.isLoading = false; })
        } catch (error) {
            console.error('Error loading PDF libraries:', error);
            this.loadError = true;
            this.isLoading = false;
            this.showToast('Error', 'Failed to load PDF libraries', 'error');
        }
    }

    /**
     * @description Handles click event for generating timesheet
     */
    async handleClick() {
        if (!this.validateDates()) return;

        try {
            this.isGeneratingPDF = true;

            this.totalDuration = 0;
            this.totalDays = 0;

            // Parallel data fetching
            const [employeeData, lineItems] = await Promise.all([
                this.fetchEmployeeData(),
                this.fetchTimesheetData()
            ]);

            if (!lineItems?.length) {
                this.showToast('Warning', 'No Timesheet Items found for the selected period.', 'warning');
                return;
            }

            this.Employee = employeeData;

            this.processTimesheetData(lineItems);
            
            await this.handleGeneratePDF();
            
        } catch (error) {
            console.error('Error processing timesheet:', error);
            if (error.message !== 'No timesheet items found') {
                this.showToast('Error', 'Error generating timesheet', 'error');
            }
        } finally {
            this.isGeneratingPDF = false;
        }
    }

    /**
     * @description Validates date inputs
     */
    validateDates() {
        const startDate = this.template.querySelector('.start-date');
        const endDate = this.template.querySelector('.end-date');

        if (!startDate.value || !endDate.value) {
            this.showToast('Warning', 'Please enter start and end date', 'warning');
            return false;
        }

        this.sd = new Date(startDate.value);
        this.ed = new Date(endDate.value);

        if (this.ed < this.sd) {
            this.showToast('Warning', 'End date must be after start date', 'warning');
            return false;
        }

        this.startDate = this.sd.toISOString().split("T")[0];
        this.endDate = this.ed.toISOString().split("T")[0];

        return true;
    }

    /**
     * @description Fetches employee data
     */
    async fetchEmployeeData() {
        try {
            const employee = await getEmployee({ recID: this.recordId });
            this.Client = employee.Project_Employees__r
                ?.map(el => el.Project_Name__c)
                .join(', ') || '';
            return employee;
        } catch (error) {
            console.error('Error fetching employee:', error);
            throw error;
        }
    }

    /**
     * @description Fetches timesheet data
     */
    async fetchTimesheetData() {
        try {
            return await getTimesheetsLineItems({
                recID: this.recordId,
                startDate: this.sd,
                endDate: this.ed
            });
        } catch (error) {
            console.error('Error fetching timesheets:', error);
            throw error;
        }
    }
	
    /**
     * @description Processes timesheet data
     */
    processTimesheetData(lineItems) {
        this.processLineItems(lineItems);
        this.addTotalRow();
    }

    /**
     * @description Processes timesheet line items
     */
    processLineItems(lineItems) {
        let dateCursor = new Date(this.startDate);
        const endDate = new Date(this.endDate);

        const tempLineItems = [];
        while (dateCursor <= endDate) {
            const yyyyMmDd = dateCursor.toISOString().split('T')[0]; // "YYYY-MM-DD" format
            tempLineItems.push({
                Date__c: yyyyMmDd,
                duration: "0",
                Day: this.weekdays[dateCursor.getDay()]
            });
            
            dateCursor.setDate(dateCursor.getDate() + 1);
            this.totalDays++;
        }

        lineItems.forEach(item => {
            const match = tempLineItems.find(row => row.Date__c === item.Date__c);
            if (match) {
                match.duration = item.duration.toString();
            }

            this.totalDuration += parseFloat(item.duration || 0);
        });

        this.TimesheetLineItems = tempLineItems;
    }

    /**
     * @description Adds total row
     */
    addTotalRow() {
        this.TimesheetLineItems.push({
            Day: "Total",
            Date__c: this.totalDays.toString(),
            duration: this.totalDuration.toString()
        });
    }

    /**
     * @description Generates PDF
     */
    async handleGeneratePDF() {
        if (!this.validatePDFGeneration()) return;

        try {
            const doc = new window.jspdf.jsPDF({
                orientation: 'portrait',
                unit: 'mm',
                format: 'a4'
                // , compress: true  // Not Compressing faster execution, but increases file size.
            });

            this.addPDFContent(doc);
            doc.save(`${this.Employee?.Name || "Unknown Contractor"}_Timesheet_${this.startDate}_${this.endDate}.pdf`);
            this.showToast('Success', 'PDF generated successfully', 'success');
        } catch (error) {
            console.error('Error generating PDF:', error);
            this.showToast('Error', 'Failed to generate PDF', 'error');
            throw error;
        }
    }

    /**
     * @description Validates PDF generation
     */
    validatePDFGeneration() {
        if (this.loadError) {
            this.showToast('Error', 'PDF libraries failed to load', 'error');
            return false;
        }
        if (this.isLoading) {
            this.showToast('Warning', 'Please wait, libraries are loading', 'warning');
            return false;
        }
        if (!this.jsPDFInitialized) {
            this.showToast('Error', 'PDF library not initialized', 'error');
            return false;
        }
        return true;
    }

    /**
     * @description Adds content to PDF
     */
    addPDFContent(doc) {
        this.addHeader(doc);
        this.addTable(doc);
    }

    /**
     * @description Adds header to PDF
     */
    addHeader(doc) {
        const contractorName = this.Employee?.Name || "Unknown Contractor";
        const clientmanagerName = this.Employee?.Client_Manager__r?.Name || "Unknown Manager";
        const clientmanagerEmail = this.Employee?.Client_Manager_email__c || "No Email Provided";

        const pic = new Image();
        pic.src = imageLogo;

        doc.setFontSize(22);
        doc.setTextColor(0, 56, 101);
        doc.text(`Timesheet_${this.startDate || 'NA'}_${this.endDate || 'Na'}`, 18, this.tableRowStart - 20); 
        doc.setFontSize(12);
        doc.setTextColor(0, 0, 0);

        doc.setDrawColor(123, 0, 166);
        doc.line(15, 34, 195, 34);
        doc.line(15, 35, 195, 35);

        doc.text("Name of Contractor: " + contractorName, 15, this.tableRowStart);
        doc.addImage(pic, 165, 2, 30, 30);
        doc.text("Client: " + this.Client, 15, this.tableRowStart + 10);
        doc.text("Name of Manager: " + clientmanagerName, 15, this.tableRowStart + 20);
        doc.text("Period Ending: " + this.endDate, 15, this.tableRowStart + 30);
        doc.text("Please email Completed & Signed to: " + clientmanagerEmail, 15, this.tableRowStart + 40);
    }

    /**
     * @description Adds table to PDF
     */
    addTable(doc) {
        const footer = [this.TimesheetLineItems.pop()];
        const columns = [
            { header: "Day", dataKey: "Day" },
            { header: "Date", dataKey: "Date__c" },
            { header: "Hours_Worked", dataKey: "duration" }
        ];
        const rows = this.TimesheetLineItems.map(row => ({
            Day: row.Day,
            Date__c: row.Date__c,
            duration: row.duration,
        }));

        doc.autoTable({
            theme: 'grid',
            columns: columns,
            body: rows,
            foot: footer,
            startY: this.tableRowStart + 50,
            // alternateRowStyles: { fillColor: [245, 245, 245] },
            headStyles: {
                fillColor: [0, 56, 101],
                textColor: [255, 255, 255],
                fontSize: 13,
                fontStyle: 'bold',
                cellPadding: 2.5,
                valign: 'middle',
                halign: 'center'
            },
            bodyStyles: {
                fontSize: 11,
                cellPadding: 1.5,
                valign: 'middle',
                halign: 'center'
            },
            footStyles: {
                fillColor: [157, 196, 75],
                textColor: [255, 255, 255],
                fontStyle: 'bold',
                fontSize: 12,
                cellPadding: 2.5,
                valign: 'middle',
                halign: 'center'
            },
            didParseCell: this.handleCellStyling
        });
    }

    /**
     * @description Handles cell styling
     */
    handleCellStyling(data) {
        const { row, cell, column } = data;
        const day = row.raw?.Day;
        const duration = row.raw?.duration;

        if (column.dataKey === 'duration' && duration === '0') {
            cell.styles.fillColor = [255, 207, 170];
        }

        if (day === 'Saturday' || day === 'Sunday') {
            cell.styles.fillColor = [230, 230, 230];
        }
    }

    get generateButtonLabel() {
        return this.isGeneratingPDF ? 'Generating PDF...' : 'Generate PDF';
    }

    get isButtonDisabled() {
        return this.isGeneratingPDF || this.isLoading;
    }
}