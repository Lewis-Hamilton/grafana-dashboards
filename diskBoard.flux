import "dict"

// key is manufacturer name
// col is my column name
// field is whether the attribute is stored as a value or raw value
// scale is the bytes multiplyer
// offset is for percentages 
// smart_attribute value 
attrMap = dict.fromList(pairs: [
  // Life remaining (normalized `value`, 100 = new)
  {key: "SSD_Life_Left",           value: {col: "Life Remaining", field: "value",     scale: 1.0,  offset: 0.0}},
  {key: "Wear_Leveling_Count",     value: {col: "Life Remaining", field: "value",     scale: 1.0,  offset: 0.0}},
  {key: "Media_Wearout_Indicator", value: {col: "Life Remaining", field: "value",     scale: 1.0,  offset: 0.0}},
  {key: "Percent_Lifetime_Remain", value: {col: "Life Remaining", field: "value",     scale: 1.0,  offset: 0.0}},
  {key: "Percentage_Used",         value: {col: "Life Remaining", field: "raw_value", scale: -1.0, offset: 100.0}},
  // Writes / reads, converted to bytes
  {key: "Lifetime_Writes_GiB",     value: {col: "Writes", field: "raw_value", scale: 1073741824.0, offset: 0.0}},
  {key: "Total_LBAs_Written",      value: {col: "Writes", field: "raw_value", scale: 512.0,        offset: 0.0}},
  {key: "Host_Writes_32MiB",       value: {col: "Writes", field: "raw_value", scale: 33554432.0,   offset: 0.0}},
  {key: "Data_Units_Written",      value: {col: "Writes", field: "raw_value", scale: 512000.0,     offset: 0.0}},
  {key: "Lifetime_Reads_GiB",      value: {col: "Reads",  field: "raw_value", scale: 1073741824.0, offset: 0.0}},
  {key: "Total_LBAs_Read",         value: {col: "Reads",  field: "raw_value", scale: 512.0,        offset: 0.0}},
  {key: "Host_Reads_32MiB",        value: {col: "Reads",  field: "raw_value", scale: 33554432.0,   offset: 0.0}},
  {key: "Data_Units_Read",         value: {col: "Reads",  field: "raw_value", scale: 512000.0,     offset: 0.0}},
  // Health counters
  {key: "Reallocated_Sector_Ct",   value: {col: "Reallocated sectors",      field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Reallocated_Event_Count", value: {col: "Reallocated sectors",      field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Current_Pending_Sector",  value: {col: "Pending Sectors",  field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Offline_Uncorrectable",   value: {col: "Uncorrectable Errors",    field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Reported_Uncorrect",      value: {col: "Uncorrectable Errors",    field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "UDMA_CRC_Error_Count",    value: {col: "CRC Errors",       field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "SATA_CRC_Error_Count",    value: {col: "CRC Errors",       field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "CRC_Error_Count",         value: {col: "CRC Errors",       field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Unsafe_Shutdown_Count",   value: {col: "Unsafe Shutdowns", field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Power_Cycle_Count",       value: {col: "Power Cycles",     field: "raw_value", scale: 1.0, offset: 0.0}}
])

// smart_device FIELD name
devMap = dict.fromList(pairs: [
  {key: "temp_c",         value: {col: "Temperature",         scale: 1.0, offset: 0.0}},
  {key: "power_on_hours", value: {col: "Power On Hours", scale: 1.0, offset: 0.0}},
  {key: "health_ok",      value: {col: "Health",       scale: 1.0, offset: 0.0}}
])

// smart_device TAG (column) name
tagMap = dict.fromList(pairs: [
  {key: "serial_no", value: "Serial Number"},
  {key: "host",      value: "Host"},
  {key: "device",    value: "Device"},
  {key: "model",     value: "Model"},
  {key: "capacity",  value: "Capacity"}
])

unmappedAttr = {col: "", field: "raw_value", scale: 1.0, offset: 0.0}
lookup = (name) => dict.get(dict: attrMap, key: name, default: unmappedAttr)

unmappedDev = {col: "", scale: 1.0, offset: 0.0}
devLookup = (field) => dict.get(dict: devMap, key: field, default: unmappedDev)

attrs = from(bucket: "disk_health")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "smart_attribute")
  |> filter(fn: (r) => { m = lookup(name: r.name)  return m.col != "" and r._field == m.field })
  |> group(columns: ["serial_no", "host", "name"])
  |> last()
  |> map(fn: (r) => { m = lookup(name: r.name)
      return {r with column: m.col, _value: float(v: r._value) * m.scale + m.offset} })
  |> keep(columns: ["serial_no", "host", "column", "_value"])
  |> group(columns: ["serial_no", "host", "column"])
  |> max()
  |> group()
  |> pivot(rowKey: ["serial_no", "host"], columnKey: ["column"], valueColumn: "_value")

devs = from(bucket: "disk_health")
  |> range(start: -30d)
  |> filter(fn: (r) => r._measurement == "smart_device")
  |> filter(fn: (r) => devLookup(field: r._field).col != "")
  |> group(columns: ["serial_no", "host", "device", "model", "capacity", "_field"])
  |> last()
  |> map(fn: (r) => { m = devLookup(field: r._field)
      return {r with _field: m.col, _value: float(v: r._value) * m.scale + m.offset} })
  |> keep(columns: ["serial_no", "host", "device", "model", "capacity", "_field", "_value"])
  |> group()
  |> pivot(rowKey: ["serial_no", "host", "device", "model", "capacity"],
           columnKey: ["_field"], valueColumn: "_value")

join(tables: {d: devs, a: attrs}, on: ["serial_no", "host"])
  |> group()
  |> rename(fn: (column) => dict.get(dict: tagMap, key: column, default: column))