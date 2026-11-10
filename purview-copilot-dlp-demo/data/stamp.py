import zipfile, shutil, sys, os, re, uuid, datetime
src, out, label_guid, label_name, tenant = sys.argv[1:6]
when = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
props = [("Enabled","true"),("SetDate",when),("Method","Standard"),("Name",label_name),("SiteId",tenant),("ActionId",str(uuid.uuid4())),("ContentBits","0")]
def prop_xml(pid, name, val):
    return f'<property fmtid="{{D5CDD505-2E9C-101B-9397-08002B2CF9AE}}" pid="{pid}" name="MSIP_Label_{label_guid}_{name}"><vt:lpwstr>{val}</vt:lpwstr></property>'
zin = zipfile.ZipFile(src)
names = zin.namelist()
existing = zin.read("docProps/custom.xml").decode("utf8") if "docProps/custom.xml" in names else None
if existing:
    maxpid = max([int(x) for x in re.findall(r'pid="(\d+)"', existing)] + [1])
    body = "".join(prop_xml(maxpid + 1 + i, n, v) for i, (n, v) in enumerate(props))
    custom = existing.replace("</Properties>", body + "</Properties>")
else:
    body = "".join(prop_xml(2 + i, n, v) for i, (n, v) in enumerate(props))
    custom = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/custom-properties" '
              'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' + body + '</Properties>')
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
    for n in names:
        data = zin.read(n)
        if n == "[Content_Types].xml" and not existing:
            s = data.decode("utf8")
            s = s.replace("</Types>", '<Override PartName="/docProps/custom.xml" ContentType="application/vnd.openxmlformats-officedocument.custom-properties+xml"/></Types>')
            data = s.encode("utf8")
        elif n == "_rels/.rels" and not existing:
            s = data.decode("utf8")
            ids = [int(x) for x in re.findall(r'Id="rId(\d+)"', s)] or [0]
            s = s.replace("</Relationships>", f'<Relationship Id="rId{max(ids)+1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties" Target="docProps/custom.xml"/></Relationships>')
            data = s.encode("utf8")
        elif n == "docProps/custom.xml":
            continue
        zout.writestr(n, data)
    zout.writestr("docProps/custom.xml", custom)
print("stamped", os.path.basename(out), "->", label_name)
