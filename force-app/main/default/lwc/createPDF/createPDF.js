import getTimesheetRecords from '@salesforce/apex/GetTimesheet.getTimesheetRecords';
import getTimesheetLineItemsRecords from '@salesforce/apex/GetTimesheetLineItems.getTimesheetLineItemsRecords';
import imageLogo from '@salesforce/resourceUrl/dbtLogo';
import JS_PDF from '@salesforce/resourceUrl/jsPDF';
import jsPDFAutoTable from '@salesforce/resourceUrl/jsPdfAutotable';
import { loadScript } from 'lightning/platformResourceLoader';
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PdfGenerator extends LightningElement {
    @api recordId;
    @track isGeneratingPDF = false;

    // Private properties
    Timesheet;
    TimesheetLineItems = [];
    weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    // PDF Generation states
    jsPDFInitialized = false;
    loadError = false;
    isLoading = true;

    /**
     * @description Shows toast message
     */
    showToast(title, message, variant) {
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
     * @description Handles generate PDF button click
     */
    async handleClick() {
        if (!this.validatePDFGeneration()) return;

        try {
            this.isGeneratingPDF = true;
            await this.generateData();
            this.showToast('Success', 'PDF generated successfully', 'success');
        } catch (error) {
            console.error('Error generating PDF:', error);
            this.showToast('Error', 'Failed to generate PDF', 'error');
        } finally {
            this.isGeneratingPDF = false;
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
        return true;
    }

    /**
     * @description Generates data and creates PDF
     */
    async generateData() {
        try {
            const timesheetData = await getTimesheetRecords({ recID: this.recordId });
            this.Timesheet = timesheetData;

            const lineItems = await getTimesheetLineItemsRecords({ recId: this.recordId });
            this.processLineItems(lineItems);
            
            await this.handleGeneratePDF();
        } catch (error) {
            console.error('Error generating data:', error);
            throw error;
        }
    }

    /**
     * @description Processes timesheet line items
     */
    processLineItems(lineItems) {
        let dateCursor = new Date(this.Timesheet.dbt__Start_Date__c);
        const endDate = new Date(this.Timesheet.dbt__End_Date__c);

        const tempLineItems = [];
        while (dateCursor <= endDate) {
            const yyyyMmDd = dateCursor.toISOString().split('T')[0]; // "YYYY-MM-DD" format
            tempLineItems.push({
                dbt__Date__c: yyyyMmDd,
                duration: "0",
                Day: this.weekdays[dateCursor.getDay()]
            });
            
            dateCursor.setDate(dateCursor.getDate() + 1);
        }

        lineItems.forEach(item => {
            const match = tempLineItems.find(row => row.dbt__Date__c === item.dbt__Date__c);
            if (match) {
                match.duration = item.duration.toString();
            }
        });

        this.TimesheetLineItems = tempLineItems;
    }

    /**
     * @description Generates PDF
     */
    async handleGeneratePDF() {
        const doc = new window.jspdf.jsPDF({
            orientation: 'portrait',
            unit: 'mm',
            format: 'a4'
        });

        this.addHeader(doc);
        this.addTable(doc);

        doc.save(`${this.Timesheet?.dbt__Employee__r?.Name || "Unknown Contractor"}_Timesheet_${this.Timesheet?.dbt__End_Date__c || 'generated'}.pdf`);
    }

    /**
     * @description Adds header to PDF
     */
    addHeader(doc) {
        const contractorName = this.Timesheet?.dbt__Employee__r?.Name || "Unknown Contractor";
        const clientManagerName = this.Timesheet?.dbt__Employee__r?.Client_Manager__r?.Name || "Unknown Manager";
        const clientManagerEmail = this.Timesheet?.dbt__Employee__r?.Client_Manager_email__c || "No Email Provided";
        const fortnightEnding = this.Timesheet?.dbt__End_Date__c || "Unknown Date";
        const billableHours = this.Timesheet?.dbt__Billable_Hours__c || "0";
        const totalHours = this.Timesheet?.dbt__Total_Hours__c || "0";

        const pic = new Image();
        pic.src = imageLogo;

        doc.text("Name of Contractor: " + contractorName, 10, 10);
        doc.addImage(pic, 175, 2, 30, 30);
        doc.text("Fortnight Ending: " + fortnightEnding, 10, 20);
        doc.text("Name of Manager: " + clientManagerName, 10, 30);
        doc.text("Manager Email: " + clientManagerEmail, 10, 40);
        doc.text("Billable Hours: " + billableHours, 10, 50);
        doc.text("Total Hours: " + totalHours, 10, 60);
    }

    /**
     * @description Adds table to PDF
     */
    addTable(doc) {
        const columns = [
            { header: 'Day', dataKey: 'Day' },
            { header: 'Date', dataKey: 'dbt__Date__c' },
            { header: 'Hours Worked', dataKey: 'duration' }
        ];

        doc.autoTable({
            startY: 70,
            columns: columns,
            body: this.TimesheetLineItems,
            theme: 'grid',
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