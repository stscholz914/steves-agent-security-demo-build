import random, os, sys
from docx import Document
from docx.shared import Pt
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill

out = sys.argv[1]
random.seed(581)

def luhn_card(prefix, length=16):
    digits = [int(c) for c in prefix] + [random.randint(0, 9) for _ in range(length - len(prefix) - 1)]
    s = 0
    for i, d in enumerate(reversed(digits)):
        if i % 2 == 0:
            d = d * 2
            if d > 9: d -= 9
        s += d
    return "".join(map(str, digits)) + str((10 - s % 10) % 10)

def ssn():
    return f"{random.randint(100,665)}-{random.randint(10,99)}-{random.randint(1000,9999)}"

first = ["Avery","Jordan","Riley","Morgan","Taylor","Casey","Quinn","Rowan","Sage","Dana","Elliot","Harper","Jamie","Kai","Logan","Micah","Noel","Parker","Reese","Sky","Tatum","Wren","Blake","Cameron","Drew"]
last  = ["Nolan","Pike","Chen","Okafor","Lindqvist","Moreau","Tanaka","Delgado","Iyer","Novak","Brandt","Castillo","Dubois","Eriksen","Fischer","Gallo","Hassan","Ivanov","Jensen","Kowalski","Larsen","Mendes","Nakamura","Ortiz","Petrov"]

# 1) Customer onboarding export (PII) ------------------------------------------------
wb = Workbook(); ws = wb.active; ws.title = "Customers"
hdr = ["Customer ID","Full Name","Social Security Number","Date of Birth","Credit Card Number","Card Expiry","Email","Street Address","City","State","Annual Income"]
ws.append(hdr)
for c in ws[1]:
    c.font = Font(bold=True, color="FFFFFF"); c.fill = PatternFill("solid", fgColor="1F3864")
cities = [("Austin","TX"),("Denver","CO"),("Raleigh","NC"),("Portland","OR"),("Madison","WI"),("Tampa","FL"),("Boise","ID")]
for i in range(25):
    city, st = random.choice(cities)
    ws.append([f"CUST-{10001+i}", f"{first[i]} {last[i]}", ssn(), f"{random.randint(1955,2000)}-{random.randint(1,12):02d}-{random.randint(1,28):02d}",
               luhn_card(random.choice(["4","51","37"]), 15 if False else 16), f"{random.randint(1,12):02d}/{random.randint(28,31)}",
               f"{first[i].lower()}.{last[i].lower()}@contoso-demo.example", f"{random.randint(100,9999)} {random.choice(['Oak','Maple','Cedar','Pine','Elm'])} St", city, st, random.randint(48,240)*1000])
for col, w in zip("ABCDEFGHIJK", [13,22,24,14,22,11,36,22,12,7,14]): ws.column_dimensions[col].width = w
ws2 = wb.create_sheet("README")
ws2["A1"] = "SYNTHETIC DEMO DATA - not real customer information. Generated for a Microsoft Purview demonstration."
wb.save(os.path.join(out, "Customer-Onboarding-Export.xlsx"))

# 2) M&A plan -------------------------------------------------------------------------
doc = Document(); doc.add_heading("Project Falcon - Acquisition Plan", 0)
doc.add_paragraph("Contoso Corp. - STRICTLY CONFIDENTIAL - Board and executive team only").runs[0].bold = True
doc.add_heading("1. Summary", 1)
doc.add_paragraph("Contoso intends to acquire Northwind Labs, a robotics software company, for an enterprise value of USD 412 million. The transaction is expected to close in the fourth quarter of FY27 subject to regulatory approval. This document is material non-public information (MNPI).")
doc.add_heading("2. Financial terms", 1)
t = doc.add_table(rows=1, cols=2); t.style = "Light Grid Accent 1"
t.rows[0].cells[0].text = "Item"; t.rows[0].cells[1].text = "Value"
for k, v in [("Offer price per share","USD 38.50"),("Premium to 30-day average","31%"),("Cash / stock mix","70% / 30%"),("Expected synergies (run-rate)","USD 46 million"),("Break fee","USD 14.4 million")]:
    r = t.add_row().cells; r[0].text = k; r[1].text = v
doc.add_heading("3. Timeline", 1)
for s in ["Board approval - week 2","Signing and announcement - week 5","Antitrust filing - week 6","Expected close - week 24"]: doc.add_paragraph(s, style="List Bullet")
doc.add_heading("4. Distribution", 1)
doc.add_paragraph("Do not forward. Do not summarise with external AI tools. Questions to the Corporate Development lead.")
doc.save(os.path.join(out, "Project-Falcon-Acquisition-Plan.docx"))

# 3) Financial forecast ---------------------------------------------------------------
wb = Workbook(); ws = wb.active; ws.title = "FY27 Forecast"
ws.append(["Line item","Q1","Q2","Q3","Q4","FY27"])
for c in ws[1]: c.font = Font(bold=True)
rows = [("Revenue",812,845,901,978),("Cost of revenue",301,310,332,356),("Gross profit",None,None,None,None),("R&D",142,150,158,166),("Sales and marketing",118,124,131,139),("G&A",64,66,69,72),("Operating income",None,None,None,None)]
for i, r in enumerate(rows, start=2):
    ws.append(list(r) + [None])
for col in "BCDE":
    ws[f"{col}4"] = f"={col}2-{col}3"; ws[f"{col}8"] = f"={col}4-{col}5-{col}6-{col}7"
for r in range(2, 9): ws[f"F{r}"] = f"=SUM(B{r}:E{r})"
ws["A10"] = "Confidential - unreleased FY27 forecast, USD millions. Not for distribution outside the finance leadership team."
wb.save(os.path.join(out, "FY27-Financial-Forecast.xlsx"))

# 4) Salary bands -----------------------------------------------------------------------
wb = Workbook(); ws = wb.active; ws.title = "Bands"
ws.append(["Level","Title","Band minimum (USD)","Band midpoint (USD)","Band maximum (USD)","Equity grant (units)"])
for c in ws[1]: c.font = Font(bold=True)
for lvl, ttl, mn, md, mx, eq in [("L3","Associate Engineer",88000,102000,116000,400),("L4","Engineer",110000,128000,146000,900),("L5","Senior Engineer",138000,160000,182000,1800),("L6","Staff Engineer",172000,198000,224000,3600),("L7","Principal Engineer",208000,238000,268000,7200),("M5","Engineering Manager",176000,204000,232000,3000)]:
    ws.append([lvl, ttl, mn, md, mx, eq])
ws["A9"] = "HR Confidential - compensation bands, FY27 cycle. Managers and HR business partners only."
wb.save(os.path.join(out, "Employee-Salary-Bands.xlsx"))

# 5) Support transcript with pasted PII (oversharing example) ------------------------
doc = Document(); doc.add_heading("Support case 48213 - transcript", 0)
for who, msg in [("Agent","Thanks for contacting Contoso support. Can you confirm the account holder?"),
                 ("Customer","Sure, it's Morgan Lindqvist. My Social Security number is 412-68-3359 and the card on file is 4532 0151 1283 0366."),
                 ("Agent","Thank you Morgan. I have pulled up your account and I can see the failed payment from Tuesday."),
                 ("Customer","Right. Can you use the same card, expiry 09/29, to retry?")]:
    p = doc.add_paragraph(); p.add_run(f"{who}: ").bold = True; p.add_run(msg)
doc.save(os.path.join(out, "Support-Case-48213-Transcript.docx"))

# 6) General / public documents --------------------------------------------------------
doc = Document(); doc.add_heading("Contoso AI Acceptable Use Guidelines", 0)
doc.add_paragraph("These guidelines explain how employees may use AI tools at Contoso.")
for s in ["Use Microsoft 365 Copilot and registered company agents for work tasks.","Do not paste customer data, financial results or confidential plans into unapproved AI websites.","Check that documents carry the correct sensitivity label before sharing.","Report anything that looks wrong to the security team."]: doc.add_paragraph(s, style="List Bullet")
doc.save(os.path.join(out, "AI-Acceptable-Use-Guidelines.docx"))
doc = Document(); doc.add_heading("Contoso Holiday Calendar FY27", 0)
for s in ["New Year's Day - 1 January","Memorial Day - 25 May","Independence Day - 4 July","Labor Day - 7 September","Thanksgiving - 26 November","Winter break - 24 December to 1 January"]: doc.add_paragraph(s, style="List Bullet")
doc.save(os.path.join(out, "Holiday-Calendar-FY27.docx"))
print("generated", len(os.listdir(out)), "files")
