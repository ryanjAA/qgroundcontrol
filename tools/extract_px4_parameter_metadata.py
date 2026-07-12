#!/usr/bin/env python3
"""Extract PX4 parameter metadata XML from a .px4/.apj firmware file."""

import argparse
import base64
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
import zlib


PARAM_XML_SIZE_KEY = "parameter_xml_size"
PARAM_XML_KEY = "parameter_xml"
MAV_AUTOPILOT_KEY = "mav_autopilot"
MAV_AUTOPILOT_PX4 = 12


class MetadataExtractError(Exception):
    pass


def _default_output_path(firmware_path):
    return firmware_path.with_suffix(".parameter.xml")


def _read_firmware_json(firmware_path):
    try:
        with firmware_path.open("r", encoding="utf-8") as firmware_file:
            return json.load(firmware_file)
    except OSError as error:
        raise MetadataExtractError(f"Unable to open {firmware_path}: {error}") from error
    except json.JSONDecodeError as error:
        raise MetadataExtractError(f"{firmware_path} is not valid firmware JSON: {error}") from error


def _extract_parameter_xml(firmware_json, firmware_path):
    autopilot = firmware_json.get(MAV_AUTOPILOT_KEY)
    if autopilot is not None and autopilot != MAV_AUTOPILOT_PX4:
        raise MetadataExtractError(f"{firmware_path} is not PX4 firmware (mav_autopilot={autopilot})")

    if PARAM_XML_SIZE_KEY not in firmware_json:
        raise MetadataExtractError(f"{firmware_path} is missing {PARAM_XML_SIZE_KEY}")
    if PARAM_XML_KEY not in firmware_json:
        raise MetadataExtractError(f"{firmware_path} is missing {PARAM_XML_KEY}")

    expected_size = firmware_json[PARAM_XML_SIZE_KEY]
    if not isinstance(expected_size, int) or expected_size <= 0:
        raise MetadataExtractError(f"{firmware_path} has invalid {PARAM_XML_SIZE_KEY}")

    encoded_xml = firmware_json[PARAM_XML_KEY]
    if not isinstance(encoded_xml, str) or not encoded_xml:
        raise MetadataExtractError(f"{firmware_path} has invalid {PARAM_XML_KEY}")

    encoded_xml = "".join(encoded_xml.split())
    try:
        compressed_xml = base64.b64decode(encoded_xml, validate=True)
    except ValueError as error:
        raise MetadataExtractError(f"{firmware_path} has invalid base64 in {PARAM_XML_KEY}: {error}") from error

    try:
        parameter_xml = zlib.decompress(compressed_xml)
    except zlib.error as error:
        raise MetadataExtractError(f"Unable to decompress {PARAM_XML_KEY}: {error}") from error

    if len(parameter_xml) != expected_size:
        raise MetadataExtractError(
            f"Decompressed XML size mismatch: expected {expected_size}, got {len(parameter_xml)}"
        )

    return parameter_xml


def _validate_parameter_xml(parameter_xml, source_name):
    try:
        root = ET.fromstring(parameter_xml)
    except ET.ParseError as error:
        raise MetadataExtractError(f"Extracted parameter metadata is not valid XML: {error}") from error

    major_element = root.find(".//parameter_version_major")
    minor_element = root.find(".//parameter_version_minor")
    if major_element is None or major_element.text is None:
        raise MetadataExtractError(f"{source_name} metadata is missing parameter_version_major")
    if minor_element is None or minor_element.text is None:
        raise MetadataExtractError(f"{source_name} metadata is missing parameter_version_minor")

    try:
        major_version = int(major_element.text.strip())
        minor_version = int(minor_element.text.strip())
    except ValueError as error:
        raise MetadataExtractError(f"{source_name} metadata has an invalid parameter version") from error

    if major_version != 1:
        raise MetadataExtractError(f"{source_name} metadata has unsupported major version {major_version}")

    return major_version, minor_version


def extract_metadata(firmware_path, output_path, force):
    firmware_json = _read_firmware_json(firmware_path)
    parameter_xml = _extract_parameter_xml(firmware_json, firmware_path)
    major_version, minor_version = _validate_parameter_xml(parameter_xml, firmware_path)

    if output_path.exists() and not force:
        raise MetadataExtractError(f"{output_path} already exists; pass --force to overwrite")

    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(parameter_xml)
    except OSError as error:
        raise MetadataExtractError(f"Unable to write {output_path}: {error}") from error

    return major_version, minor_version, len(parameter_xml)


def _parse_args(argv):
    parser = argparse.ArgumentParser(
        description="Extract PX4 parameter metadata XML from a .px4/.apj firmware file."
    )
    parser.add_argument("firmware", type=Path, help="PX4 firmware file containing parameter_xml")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output XML path. Defaults to <firmware>.parameter.xml next to the firmware file.",
    )
    parser.add_argument("-f", "--force", action="store_true", help="Overwrite the output file if it already exists.")
    return parser.parse_args(argv)


def main(argv):
    args = _parse_args(argv)
    firmware_path = args.firmware
    output_path = args.output if args.output else _default_output_path(firmware_path)

    try:
        major_version, minor_version, xml_size = extract_metadata(firmware_path, output_path, args.force)
    except MetadataExtractError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(f"Wrote {output_path}")
    print(f"PX4 parameter metadata version {major_version}.{minor_version}, {xml_size} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
