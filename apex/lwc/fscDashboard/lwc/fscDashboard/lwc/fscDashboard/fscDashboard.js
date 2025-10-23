import { LightningElement, wire, track } from 'lwc';
import getSummary from '@salesforce/apex/FscDashboardController.getSummary';
import getRecent from '@salesforce/apex/FscDashboardController.getRecent';

export default class FscDashboard extends LightningElement {
  @track summary = { householdCount: 0, accountCount: 0, totalAum: 0, mode: 'FSC' };
  @track rows = [];

  columns = [
    { label: 'Name', fieldName: 'name', type: 'text' },
    { label: 'Type/Stage', fieldName: 'type', type: 'text' },
    { label: 'Last Activity', fieldName: 'lastActivity', type: 'date' },
    { label: 'Balance/Amount', fieldName: 'balance', type: 'currency' }
  ];

  get kpi2Label() {
    return this.summary.mode === 'FSC' ? 'Financial Accounts' : 'Open Opportunities';
  }

  get aumLabel() {
    return this.summary.mode === 'FSC' ? 'Total AUM' : 'Open Pipeline';
  }

  get formattedAum() {
    try {
      return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD' }).format(this.summary.totalAum || 0);
    } catch (e) {
      return this.summary.totalAum;
    }
  }

  @wire(getSummary)
  wiredSummary({ data, error }) {
    if (data) this.summary = data;
    if (error) console.error(error);
  }

  @wire(getRecent, { limitSize: 10 })
  wiredRecent({ data, error }) {
    if (data) this.rows = data;
    if (error) console.error(error);
  }
}
