#!/usr/bin/env python3
"""Convert SIEM OpenSearch Dashboards saved objects to Grafana dashboards.

This is a pragmatic converter for the saved object patterns used by this
repository. It preserves dashboard layout, titles, basic queries, and common
aggregation shapes. Some OpenSearch Dashboards visualizations don't have a
Grafana equivalent; those become text panels with conversion notes rather than
being silently dropped.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DATASOURCE = {
    "type": "grafana-opensearch-datasource",
    "uid": "siem-opensearch",
}
TIME_FIELD = "@timestamp"


def slugify(value: str, max_len: int = 40) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return (slug or "dashboard")[:max_len].strip("-")


def load_ndjson(path: Path) -> list[dict[str, Any]]:
    objects: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        obj = json.loads(line)
        if "type" in obj:
            objects.append(obj)
    return objects


def parse_json(value: str | None, default: Any) -> Any:
    if not value:
        return default
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return default


def extract_query(attributes: dict[str, Any]) -> str:
    meta = attributes.get("kibanaSavedObjectMeta", {})
    search_source = parse_json(meta.get("searchSourceJSON"), {})
    query = search_source.get("query", {})
    text = query.get("query", "") if isinstance(query, dict) else ""
    # The existing dashboards only use simple KQL predicates. Grafana's
    # OpenSearch datasource uses Lucene query syntax, and these predicates are
    # compatible after removing KQL-only quoting of field names.
    return text.replace('"', "")


def metric_agg(agg: dict[str, Any]) -> dict[str, Any]:
    params = agg.get("params", {})
    agg_type = agg.get("type", "count")
    metric = {"id": str(agg.get("id", "1")), "type": agg_type}
    if field := params.get("field"):
        metric["field"] = field
    if label := params.get("customLabel"):
        metric["meta"] = {"customLabel": label}
    return metric


def bucket_agg(agg: dict[str, Any]) -> dict[str, Any] | None:
    params = agg.get("params", {})
    agg_type = agg.get("type")
    agg_id = str(agg.get("id", "2"))
    if agg_type == "terms":
        return {
            "id": agg_id,
            "type": "terms",
            "field": params.get("field", "_index"),
            "settings": {
                "min_doc_count": "1",
                "missing": "",
                "order": params.get("order", "desc"),
                "orderBy": "_count",
                "size": str(params.get("size", 10)),
            },
        }
    if agg_type in ("date_histogram", "histogram"):
        return {
            "id": agg_id,
            "type": "date_histogram",
            "field": params.get("field", TIME_FIELD),
            "settings": {
                "interval": params.get("interval", "auto"),
                "min_doc_count": "0",
                "trimEdges": "0",
            },
        }
    if agg_type == "geohash_grid":
        return {
            "id": agg_id,
            "type": "geohash_grid",
            "field": params.get("field", "source.geo.location"),
            "settings": {"precision": str(params.get("precision", 3))},
        }
    return None


def target_from_vis(vis_state: dict[str, Any], query: str) -> dict[str, Any]:
    aggs = [agg for agg in vis_state.get("aggs", []) if agg.get("enabled", True)]
    metrics = [metric_agg(agg) for agg in aggs if agg.get("schema") == "metric"]
    buckets = [bucket_agg(agg) for agg in aggs if agg.get("schema") != "metric"]
    buckets = [bucket for bucket in buckets if bucket]
    if not metrics:
        metrics = [{"id": "1", "type": "count"}]
    return {
        "bucketAggs": buckets,
        "datasource": DATASOURCE,
        "metrics": metrics,
        "query": query,
        "refId": "A",
        "timeField": TIME_FIELD,
    }


def panel_type(vis_type: str) -> str:
    return {
        "area": "timeseries",
        "heatmap": "heatmap",
        "histogram": "barchart",
        "line": "timeseries",
        "markdown": "text",
        "metric": "stat",
        "pie": "piechart",
        "region_map": "geomap",
        "table": "table",
    }.get(vis_type, "text")


def panel_options(grafana_type: str, vis_state: dict[str, Any]) -> dict[str, Any]:
    if grafana_type == "text":
        params = vis_state.get("params", {})
        content = params.get("markdown") or params.get("text") or ""
        return {"mode": "markdown", "content": content}
    if grafana_type == "stat":
        return {"colorMode": "value", "graphMode": "area", "justifyMode": "auto"}
    if grafana_type == "piechart":
        return {"displayLabels": [], "legend": {"displayMode": "list", "placement": "right"}}
    if grafana_type == "table":
        return {"showHeader": True}
    if grafana_type == "geomap":
        return {"view": {"id": "zero", "lat": 0, "lon": 0, "zoom": 1}}
    return {}


def grid_pos(grid: dict[str, Any]) -> dict[str, int]:
    return {
        "x": int(round(grid.get("x", 0) / 2)),
        "y": int(grid.get("y", 0)),
        "w": max(1, int(round(grid.get("w", 24) / 2))),
        "h": max(1, int(grid.get("h", 8))),
    }


def unsupported_panel(panel_id: int, title: str, grid: dict[str, Any], reason: str) -> dict[str, Any]:
    return {
        "datasource": DATASOURCE,
        "fieldConfig": {"defaults": {}, "overrides": []},
        "gridPos": grid_pos(grid),
        "id": panel_id,
        "options": {"mode": "markdown", "content": f"### {title}\n\n{reason}"},
        "targets": [],
        "title": title,
        "type": "text",
    }


def visualization_panel(panel_id: int, saved: dict[str, Any], grid: dict[str, Any]) -> tuple[dict[str, Any], str | None]:
    attrs = saved.get("attributes", {})
    title = attrs.get("title", "Untitled")
    vis_state = parse_json(attrs.get("visState"), {})
    vis_type = vis_state.get("type", "")
    grafana_type = panel_type(vis_type)
    if grafana_type == "text" and vis_type != "markdown":
        reason = f"OpenSearch Dashboards visualization type `{vis_type}` has no automatic Grafana mapping."
        return unsupported_panel(panel_id, title, grid, reason), vis_type
    query = extract_query(attrs)
    panel = {
        "datasource": DATASOURCE,
        "fieldConfig": {"defaults": {}, "overrides": []},
        "gridPos": grid_pos(grid),
        "id": panel_id,
        "options": panel_options(grafana_type, vis_state),
        "targets": [] if grafana_type == "text" else [target_from_vis(vis_state, query)],
        "title": title,
        "type": grafana_type,
    }
    if grafana_type == "text":
        panel.pop("datasource", None)
    return panel, None


def search_panel(panel_id: int, saved: dict[str, Any], grid: dict[str, Any]) -> dict[str, Any]:
    attrs = saved.get("attributes", {})
    title = attrs.get("title", "Saved search")
    columns = attrs.get("columns", [])
    return {
        "datasource": DATASOURCE,
        "fieldConfig": {"defaults": {}, "overrides": []},
        "gridPos": grid_pos(grid),
        "id": panel_id,
        "options": {"showTime": True, "showLabels": False, "wrapLogMessage": False},
        "targets": [{
            "bucketAggs": [],
            "datasource": DATASOURCE,
            "metrics": [{"id": "1", "type": "logs"}],
            "query": extract_query(attrs),
            "refId": "A",
            "timeField": TIME_FIELD,
        }],
        "title": title + (f" ({', '.join(columns)})" if columns else ""),
        "type": "logs",
    }


def convert_dashboard(
        path: Path,
        catalog: dict[tuple[str, str], dict[str, Any]]) -> tuple[dict[str, Any], dict[str, Any]]:
    objects = load_ndjson(path)
    by_key = {**catalog, **{(obj["type"], obj["id"]): obj for obj in objects if "id" in obj}}
    dashboard = next(obj for obj in objects if obj.get("type") == "dashboard")
    attrs = dashboard["attributes"]
    panels_json = parse_json(attrs.get("panelsJSON"), [])
    refs = {ref["name"]: (ref["type"], ref["id"]) for ref in dashboard.get("references", [])}

    panels: list[dict[str, Any]] = []
    unsupported: dict[str, int] = {}
    for index, panel_ref in enumerate(panels_json, start=1):
        ref_name = panel_ref.get("panelRefName")
        key = refs.get(ref_name)
        grid = panel_ref.get("gridData", {})
        if not key or key not in by_key:
            panels.append(unsupported_panel(index, "Missing panel", grid, "Referenced saved object was not found."))
            unsupported["missing"] = unsupported.get("missing", 0) + 1
            continue
        saved = by_key[key]
        if saved["type"] == "visualization":
            panel, unsupported_type = visualization_panel(index, saved, grid)
            panels.append(panel)
            if unsupported_type:
                unsupported[unsupported_type] = unsupported.get(unsupported_type, 0) + 1
        elif saved["type"] == "search":
            panels.append(search_panel(index, saved, grid))
        else:
            panels.append(unsupported_panel(index, saved.get("attributes", {}).get("title", saved["type"]), grid,
                                            f"Saved object type `{saved['type']}` is not a panel."))
            unsupported[saved["type"]] = unsupported.get(saved["type"], 0) + 1

    title = attrs.get("title", path.stem)
    converted = {
        "annotations": {"list": []},
        "editable": True,
        "fiscalYearStartMonth": 0,
        "graphTooltip": 0,
        "id": None,
        "links": [],
        "liveNow": False,
        "panels": panels,
        "refresh": "30s",
        "schemaVersion": 39,
        "tags": ["siem", "converted-from-opensearch-dashboards"],
        "templating": {"list": []},
        "time": {"from": "now-24h", "to": "now"},
        "timepicker": {},
        "timezone": "browser",
        "title": title,
        "uid": f"siem-{slugify(title)}",
        "version": 1,
        "weekStart": "",
    }
    summary = {
        "source": str(path),
        "title": title,
        "panels": len(panels),
        "unsupported": unsupported,
    }
    return converted, summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("source/saved_objects/each-dashboard"))
    parser.add_argument("--catalog-root", type=Path, default=Path("source/saved_objects"))
    parser.add_argument("--output", type=Path, default=Path("source/lambda/deploy_es/grafana_dashboards"))
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    catalog: dict[tuple[str, str], dict[str, Any]] = {}
    for source in sorted(args.catalog_root.rglob("*.ndjson")):
        for obj in load_ndjson(source):
            if "id" in obj:
                catalog[(obj["type"], obj["id"])] = obj

    report = []
    for source in sorted(args.input.glob("*.ndjson")):
        dashboard, summary = convert_dashboard(source, catalog)
        dest = args.output / f"{slugify(summary['title'])}.json"
        dest.write_text(json.dumps(dashboard, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        report.append({**summary, "output": str(dest)})
    (args.output / "conversion_report.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Converted {len(report)} dashboards into {args.output}")


if __name__ == "__main__":
    main()
