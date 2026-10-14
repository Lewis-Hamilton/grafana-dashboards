from(bucket: "disk_health")
  |> range(start: -30d)
  |> filter(fn: (r) => r["_measurement"] == "smart_device")
  |> group(columns: ["serial_no", "host", "device", "model", "capacity", "_field"])
  |> last()
  |> map(fn: (r) => ({ r with _value: float(v: r._value) }))
  |> group(columns: ["serial_no", "host", "device", "model", "capacity"])
  |> pivot(
      rowKey: ["serial_no", "host", "device", "model", "capacity"],
      columnKey: ["_field"],
      valueColumn: "_value"
  )
  |> drop(columns: ["_time", "_start", "_stop", "_measurement"])
  |> group()