import "dict"

// key is manufacturer name
// col is my column name
// field is whether the attribute is stored as a value or raw value
// scale is the bytes multiplyer
// offset is for percentages 
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
  {key: "Offline_Uncorrectable",   value: {col: "Uncorrectable",    field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Reported_Uncorrect",      value: {col: "Uncorrectable",    field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "UDMA_CRC_Error_Count",    value: {col: "CRC Errors",       field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "SATA_CRC_Error_Count",    value: {col: "CRC Errors",       field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "CRC_Error_Count",         value: {col: "CRC Errors",       field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Unsafe_Shutdown_Count",   value: {col: "Unsafe Shutdowns", field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Power_On_Hours",          value: {col: "Power On Hours",   field: "raw_value", scale: 1.0, offset: 0.0}},
  {key: "Power_Cycle_Count",       value: {col: "Power Cycles",     field: "raw_value", scale: 1.0, offset: 0.0}}
])

unmapped = {col: "", field: "raw_value", scale: 1.0, offset: 0.0}
lookup = (name) => dict.get(dict: attrMap, key: name, default: unmapped)

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
  |> filter(fn: (r) => r._measurement == "smart_device" and r._field == "temp_c")
  |> group(columns: ["serial_no", "host"])
  |> last()
  |> group()
  |> keep(columns: ["serial_no", "host", "device", "model", "capacity", "_value"])

join(tables: {d: devs, a: attrs}, on: ["serial_no", "host"])
  |> group()