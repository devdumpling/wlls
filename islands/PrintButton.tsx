export default function PrintButton() {
  return (
    <button class="print-button" type="button" onClick={() => globalThis.print()}>
      Print or save as PDF
    </button>
  );
}
