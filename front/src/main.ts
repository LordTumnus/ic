import { mount } from 'svelte'

declare global {
  interface Window {
    setup: (matlabHtml: any) => void;
  }
}

let mHtml: any


window.setup = (matlabHtml: any) => {
  // store the html component -> to be later used by components
  mHtml = matlabHtml;
  mHtml.addEventListener("DataChanged", async () => {
      for (const event of mHtml!.Data) {
          // dispatch the event to the relevant component
      }
  })
};
