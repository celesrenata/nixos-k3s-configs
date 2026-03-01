import xml.etree.ElementTree as ET
import sys
import tempfile
import logging

# Set up logging to help with debugging (output at ERROR level)
logging.basicConfig(level=logging.ERROR)
logger = logging.getLogger(__name__)

def main():
    try:
        # Read input XML from file
        orig_xml_file_path = '/tmp/orig.xml'
        logger.info(f"Reading original XML from: {orig_xml_file_path}")
        with open(orig_xml_file_path, 'r') as orig_xml_file:
            orig_xml = orig_xml_file.read()

        # Parse XML and modify bus and slot attributes
        root = ET.fromstring(orig_xml)

        for addr in root.findall('.//address[@type="pci"]'):
            if addr.attrib.get('bus', None) == '0x08':
                addr.set('bus', '0x00')
                addr.set('slot', '0x02')

        # Create output XML string
        modified_xml_str = ET.tostring(root, encoding='unicode')

        # Write modified XML to new file
        orig_new_xml_file_path = '/tmp/orig.new.xml'
        logger.info(f"Writing modified XML to: {orig_new_xml_file_path}")
        with open(orig_new_xml_file_path, 'w') as orig_new_xml_file:
            orig_new_xml_file.write(modified_xml_str)

    except Exception as e:
        logger.error(f"Error occurred while processing XML: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
