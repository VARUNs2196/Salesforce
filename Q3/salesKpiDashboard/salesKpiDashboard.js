/* eslint-disable @lwc/lwc/no-async-operation */
import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getKpiSummary from "@salesforce/apex/KpiDashBoardController.getKpiSummary";
import generateCSV from "@salesforce/apex/KpiDashBoardController.generateCSV";
import { publish, MessageContext } from "lightning/messageService";
import REGION_CHANNEL from "@salesforce/messageChannel/RegionChangeChannel__c";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import OPPORTUNITY_OBJECT from "@salesforce/schema/Opportunity";
import REGION_FIELD from "@salesforce/schema/Opportunity.Region__c";
import CARD_CHANNEL from "@salesforce/messageChannel/CardClickChannel__c";
export default class SalesKpiDashboard extends LightningElement {
  OppRecordTypeId;
  error;
  selectedRegion = "None";
  regionOptions = [];
  openPipelineVal = "$0";
  wonRevenueVal = "$0";
  avgDealSizeVal = "$0";
  winRateVal = "0%";

  openPipelineTrend = "flat";
  wonRevenueTrend = "flat";
  avgDealSizeTrend = "flat";
  winRateTrend = "flat";

  activeCardId = "";
  activeCardTitle = "";

  refreshIntervalId;
  wiredKpiPayload;

  @wire(MessageContext)
  messageContext;

  @wire(getObjectInfo, { objectApiName: OPPORTUNITY_OBJECT })
  objectInfoResults({ error, data }) {
    if (data) {
      this.OppRecordTypeId = data.defaultRecordTypeId;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.OppRecordTypeId = undefined;
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$OppRecordTypeId",
    fieldApiName: REGION_FIELD
  })
  picklistResults({ error, data }) {
    if (data) {
      console.log("Region Picklist Values: " + JSON.stringify(data));
      this.regionOptions = data.values.map((picklistEntry) => ({
        label: picklistEntry.label,
        value: picklistEntry.value
      }));
      this.regionOptions.unshift({ label: "None", value: "None" });
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.regionOptions = [];
    }
  }
  @wire(getKpiSummary, { region: "$selectedRegion" })
  wiredKpiSummary(result) {
    this.wiredKpiPayload = result;
    const { error, data } = result;

    if (data) {
      this.openPipelineTrend = this.calculateTrend(
        this.openPipelineVal,
        data.openPipeline
      );
      this.wonRevenueTrend = this.calculateTrend(
        this.wonRevenueVal,
        data.wonRevenue
      );
      this.avgDealSizeTrend = this.calculateTrend(
        this.avgDealSizeVal,
        data.avgDealSize
      );
      this.winRateTrend = this.calculateTrend(this.winRateVal, data.winRate);

      this.openPipelineVal = data.openPipeline || "$0";
      this.wonRevenueVal = data.wonRevenue || "$0";
      this.avgDealSizeVal = data.avgDealSize || "$0";
      this.winRateVal = data.winRate || "0%";
    } else if (error) {
      console.error("Dashboard Fetch Failure:", error);
    }
  }

  calculateTrend(oldVal, newVal) {
    if (!oldVal || !newVal) return "flat";
    const oldNum = parseFloat(String(oldVal).replace(/[^0-9.-]/g, ""));
    const newNum = parseFloat(String(newVal).replace(/[^0-9.-]/g, ""));

    if (isNaN(oldNum) || isNaN(newNum)) return "flat";
    if (newNum > oldNum) return "up";
    if (newNum < oldNum) return "down";
    return "flat";
  }

  connectedCallback() {
    this.startAutoRefresh();
  }

  disconnectedCallback() {
    this.stopAutoRefresh();
  }

  startAutoRefresh() {
    this.refreshIntervalId = setInterval(() => {
      console.log("30-Second Refresh Cycle Triggered...");
      if (this.wiredKpiPayload) {
        refreshApex(this.wiredKpiPayload)
          .then(() => {
            console.log("Dashboard KPI data refreshed successfully.");
          })
          .catch((error) => {
            console.error("Error refreshing dashboard KPI data:", error);
          });
      }
    }, 30000);
  }

  stopAutoRefresh() {
    if (this.refreshIntervalId) {
      clearInterval(this.refreshIntervalId);
    }
  }

  handleCardSelection(event) {
    this.activeCardId = event.detail.cardId;
    this.activeCardTitle = event.detail.title;
    console.log(
      `Active Detail Context Focus Shifted To: ${this.activeCardTitle} (${this.activeCardId})`
    );
    const payload = {
      kpiType: this.activeCardId,
      kpiTitle: this.activeCardTitle
    };
    publish(this.messageContext, CARD_CHANNEL, payload);
  }

  handleRegionChange(event) {
    this.selectedRegion = event.detail.value;
    const payload = { region: this.selectedRegion };
    publish(this.messageContext, REGION_CHANNEL, payload);
  }
  handleExport() {
    generateCSV()
      .then((csvData) => {
        let url;
        let isBlob = true;
        try {
          const blob = new Blob([csvData], {
            type: "text/plain;charset=utf-8;"
          });
          url = URL.createObjectURL(blob);
        } catch {
          isBlob = false;
          url = "data:text/csv;charset=utf-8," + encodeURIComponent(csvData);
        }

        const downloadElement = document.createElement("a");
        downloadElement.href = url;
        downloadElement.download = "Top_50_Opportunities.csv";
        downloadElement.style.display = "none";
        this.template.appendChild(downloadElement);
        downloadElement.click();
        this.template.removeChild(downloadElement);

        if (isBlob) {
          URL.revokeObjectURL(url);
        }
      })
      .catch((error) => {
        console.error("CSV Export failed", error);
      });
  }
}