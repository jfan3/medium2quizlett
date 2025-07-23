import io
import os
import re
from typing import List, Dict, Any, Tuple, Optional
from PIL import Image, ImageDraw
import PyPDF2
from pdf2image import convert_from_bytes
import base64
import numpy as np
from scipy import ndimage
from scipy.ndimage import binary_erosion, binary_dilation
import fitz  # PyMuPDF

class PDFProcessor:
    """Service for extracting text and images from PDF documents"""
    
    def __init__(self):
        self.image_quality = 300  # DPI for image extraction
    
    def extract_text_and_metadata(self, pdf_bytes: bytes) -> Dict[str, Any]:
        """Extract text content and metadata from PDF"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            
            # Extract basic page count
            num_pages = len(pdf_reader.pages)
            
            # Extract metadata - be more defensive about accessing metadata
            metadata = {
                "num_pages": num_pages,
                "title": "",
                "author": "",
                "creator": "",
            }
            
            # Try to extract metadata fields safely
            try:
                if pdf_reader.metadata:
                    metadata["title"] = pdf_reader.metadata.get("/Title", "") or ""
                    metadata["author"] = pdf_reader.metadata.get("/Author", "") or ""
                    metadata["creator"] = pdf_reader.metadata.get("/Creator", "") or ""
            except Exception as e:
                print(f"Warning: Could not extract PDF metadata: {e}")
            
            # Extract text by page
            pages_text = []
            for page_num, page in enumerate(pdf_reader.pages, 1):
                try:
                    text = page.extract_text()
                    pages_text.append({
                        "page_number": page_num,
                        "text": text,
                        "word_count": len(text.split()) if text else 0
                    })
                except Exception as e:
                    pages_text.append({
                        "page_number": page_num,
                        "text": "",
                        "word_count": 0,
                        "error": str(e)
                    })
            
            # Combine all text
            full_text = "\n\n".join([page["text"] for page in pages_text if page["text"]])
            
            # Enhanced title extraction - try to find title from content if metadata is empty
            if not metadata["title"] and full_text:
                extracted_title = self._extract_title_from_content(full_text)
                if extracted_title:
                    metadata["title"] = self._clean_extracted_title(extracted_title)
            
            return {
                "text": full_text,
                "pages": pages_text,
                "metadata": metadata,
                "num_pages": num_pages,  # Make sure num_pages is available at top level
                "title": metadata["title"],  # Make title available at top level
                "author": metadata["author"],  # Make author available at top level
                "total_words": sum(page["word_count"] for page in pages_text)
            }
            
        except Exception as e:
            raise Exception(f"Failed to extract text from PDF: {str(e)}")
    
    def _extract_title_from_content(self, text: str) -> str:
        """Extract title from document content using various heuristics"""
        lines = text.split('\n')
        
        # Remove empty lines and clean whitespace
        clean_lines = [line.strip() for line in lines if line.strip()]
        
        if not clean_lines:
            return ""
        
        # Strategy 1: Look for lines that appear to be titles (common patterns)
        for i, line in enumerate(clean_lines[:10]):  # Check first 10 lines
            # Skip very short lines (likely not titles)
            if len(line) < 5:
                continue
                
            # Skip lines that look like URLs, dates, or metadata
            if any(pattern in line.lower() for pattern in ['http', 'www.', '@', '.com', '.org']):
                continue
                
            # Skip lines with lots of numbers/symbols (likely not titles)
            if len(re.findall(r'[0-9/\-:.,]', line)) > len(line) * 0.3:
                continue
                
            # Handle lines that start with dates/timestamps but may contain titles
            date_match = re.match(r'^\d{1,2}/\d{1,2}/\d{2,4}[,\s]*\d{1,2}:\d{2}\s*[AP]M\s*(.+)', line)
            if date_match:
                potential_title = date_match.group(1).strip()
                if len(potential_title) > 10 and not re.match(r'^https?://', potential_title):
                    return potential_title
            
            # Look for title-like patterns
            # 1. Lines that are significantly longer than others nearby
            if len(line) > 20 and i < 5:
                # Check if this line is much longer than surrounding lines
                surrounding_lengths = [len(clean_lines[j]) for j in range(max(0, i-2), min(len(clean_lines), i+3)) if j != i]
                if surrounding_lengths and len(line) > max(surrounding_lengths) * 1.2:
                    return line
            
            # 2. Lines that contain common title words and are properly capitalized
            title_indicators = ['explained', 'introduction', 'guide', 'tutorial', 'overview', 'analysis']
            if any(indicator in line.lower() for indicator in title_indicators):
                # Check if it's properly capitalized (title case or sentence case)
                words = line.split()
                if len(words) > 1 and (words[0][0].isupper() or sum(1 for w in words if w and w[0].isupper()) >= len(words) * 0.5):
                    return line
        
        # Strategy 2: Look for the longest line in the first few lines (likely title)
        if clean_lines:
            first_few_lines = clean_lines[:5]
            longest_line = max(first_few_lines, key=len)
            if len(longest_line) > 15:  # Reasonable minimum for a title
                return longest_line
        
        # Strategy 3: Return first substantial line as fallback
        for line in clean_lines[:3]:
            if len(line) > 10 and not line.isdigit():
                return line
        
        return ""
    
    def _clean_extracted_title(self, title: str) -> str:
        """Clean up extracted title by removing timestamps, URLs, and other noise"""
        # Remove date/time patterns from the beginning (handle various formats)
        title = re.sub(r'^\d{1,2}/\d{1,2}/\d{2,4}[,\s]*\d{1,2}:\d{2}\s*[AP]M\s*', '', title)
        
        # Split on common separators and take the longest meaningful part
        # This helps extract "Mixture of Experts Explained" from "1/30/24, 11:46 AM Mixture of Experts Explained"
        parts = re.split(r'\s+(?:https?://|www\.)', title)
        if len(parts) > 1:
            # Take the part before any URL
            title = parts[0]
        
        # Remove common web artifacts
        title = re.sub(r'\s*https?://[^\s]+', '', title)
        title = re.sub(r'\s*www\.[^\s]+', '', title)
        
        # Clean up extra whitespace and common artifacts
        title = re.sub(r'\s+', ' ', title)  # Multiple spaces to single space
        title = title.strip()
        
        return title
    
    def extract_images(self, pdf_bytes: bytes, max_images: int = 500) -> List[Dict[str, Any]]:
        """Extract images from PDF pages"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            total_pages = len(pdf_reader.pages)
            
            # For textbooks, extract from all pages but limit total images
            last_page = min(total_pages, max_images) if max_images < total_pages else total_pages
            
            # Convert PDF pages to images
            images = convert_from_bytes(
                pdf_bytes,
                dpi=self.image_quality,
                first_page=1,
                last_page=last_page
            )
            
            extracted_images = []
            for page_num, img in enumerate(images, 1):
                # Convert to base64 for storage/transmission
                img_buffer = io.BytesIO()
                img.save(img_buffer, format='PNG', optimize=True, quality=85)
                img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
                
                extracted_images.append({
                    "page_number": page_num,
                    "image_base64": img_base64,
                    "width": img.width,
                    "height": img.height,
                    "format": "PNG"
                })
            
            return extracted_images
            
        except Exception as e:
            print(f"Image extraction failed (poppler might not be installed): {str(e)}")
            return []  # Return empty list instead of raising exception
    
    def save_images_to_folder(self, pdf_bytes: bytes, output_folder: str, max_images: int = 500) -> List[Dict[str, Any]]:
        """Extract images from PDF and save them to a local folder (overwrites existing images)"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            total_pages = len(pdf_reader.pages)
            
            # Create output folder if it doesn't exist, or clear it if it does
            if os.path.exists(output_folder):
                # Remove existing images to avoid confusion
                for filename in os.listdir(output_folder):
                    if filename.endswith('.png'):
                        os.remove(os.path.join(output_folder, filename))
                print(f"Cleared existing images from {output_folder}")
            else:
                os.makedirs(output_folder)
                print(f"Created new folder: {output_folder}")
            
            # For textbooks, extract from all pages but limit total images
            last_page = min(total_pages, max_images) if max_images < total_pages else total_pages
            
            print(f"Extracting images from {last_page} pages...")
            
            # Convert PDF pages to images
            images = convert_from_bytes(
                pdf_bytes,
                dpi=self.image_quality,
                first_page=1,
                last_page=last_page
            )
            
            extracted_images = []
            for page_num, img in enumerate(images, 1):
                # Save image to file (overwrites if exists)
                image_filename = f"page_{page_num:03d}.png"
                image_path = os.path.join(output_folder, image_filename)
                img.save(image_path, format='PNG', optimize=True, quality=85)
                
                extracted_images.append({
                    "page_number": page_num,
                    "image_path": image_path,
                    "image_filename": image_filename,
                    "width": img.width,
                    "height": img.height,
                    "format": "PNG",
                    "file_size_kb": os.path.getsize(image_path) // 1024
                })
                
                if page_num % 50 == 0:  # Progress indicator
                    print(f"  Processed {page_num}/{last_page} pages...")
            
            print(f"Successfully extracted and saved {len(extracted_images)} images to {output_folder}")
            return extracted_images
            
        except Exception as e:
            print(f"Image extraction and saving failed: {str(e)}")
            return []
    
    def _detect_figures_in_image(self, page_image: Image.Image) -> List[Dict[str, Any]]:
        """Detect and extract actual figures/diagrams from a page image using improved computer vision"""
        try:
            # Convert to numpy array for processing
            img_array = np.array(page_image.convert('RGB'))
            height, width = img_array.shape[:2]
            
            # Convert to grayscale for analysis
            gray = np.array(page_image.convert('L'))
            
            # Look for actual graphical elements (diagrams, charts, flowcharts)
            from scipy import ndimage
            from scipy.ndimage import binary_dilation, binary_erosion, label
            
            # Enhanced approach to detect actual figures/diagrams
            # 1. Find areas with geometric shapes (rectangles, lines, arrows)
            # 2. Look for connected visual elements that form diagrams
            
            # Detect strong edges (diagram boundaries, boxes, arrows)
            edges = ndimage.sobel(gray)
            
            # Create binary mask for strong visual elements
            edge_threshold = np.percentile(edges, 85)  # Top 15% of edges
            strong_edges = edges > edge_threshold
            
            # Look for rectangular/geometric structures typical of diagrams
            # Use morphological operations to connect nearby diagram elements
            structure = np.ones((3, 3))  # Smaller structure to preserve details
            dilated = binary_dilation(strong_edges, structure=structure, iterations=3)  # More dilation to connect elements
            eroded = binary_erosion(dilated, structure=structure, iterations=2)
            
            # Find connected components (potential diagram regions)
            labeled_regions, num_regions = label(eroded)
            
            figures = []
            min_area = 25000  # Much larger minimum area for complete diagrams
            max_area = width * height * 0.8  # Allow very large regions for complex diagrams
            
            for region_id in range(1, num_regions + 1):
                # Get bounding box of this region
                region_mask = labeled_regions == region_id
                region_coords = np.where(region_mask)
                
                if len(region_coords[0]) == 0:
                    continue
                
                y_min, y_max = region_coords[0].min(), region_coords[0].max()
                x_min, x_max = region_coords[1].min(), region_coords[1].max()
                
                region_width = x_max - x_min
                region_height = y_max - y_min
                region_area = region_width * region_height
                
                # Filter by size - diagrams should be substantial but not too large
                if region_area < min_area or region_area > max_area:
                    continue
                
                # Check aspect ratio - allow wider range for different diagram types
                aspect_ratio = region_width / region_height if region_height > 0 else 0
                if aspect_ratio < 0.2 or aspect_ratio > 8:  # More flexible aspect ratio
                    continue
                
                # Check if this region contains actual diagram elements
                region_crop = gray[y_min:y_max, x_min:x_max]
                if self._contains_diagram_elements(region_crop):
                    figures.append((x_min, y_min, x_max, y_max))
            
            # Extract the detected figures
            extracted_figures = []
            for i, bbox in enumerate(figures):
                x1, y1, x2, y2 = bbox
                
                # Add substantial padding around the figure to capture complete diagrams
                padding = 80  # Much larger padding for complete figure capture
                x1 = max(0, x1 - padding)
                y1 = max(0, y1 - padding)
                x2 = min(width, x2 + padding)
                y2 = min(height, y2 + padding)
                
                # Extract the figure region
                figure_img = page_image.crop((x1, y1, x2, y2))
                
                # Final validation - ensure this is actually a diagram
                if self._is_actual_diagram(figure_img):
                    extracted_figures.append({
                        'image': figure_img,
                        'bbox': (x1, y1, x2, y2),
                        'confidence': 0.8  # Higher confidence for improved detection
                    })
            
            return extracted_figures
            
        except Exception as e:
            print(f"Figure detection failed: {str(e)}")
            return []
    
    def _expand_figure_region(self, edges, start_x, start_y, initial_size, min_size):
        """Expand a region to encompass the full figure"""
        try:
            height, width = edges.shape
            
            # Find the bounding box of connected visual elements
            x1, y1 = start_x, start_y
            x2, y2 = start_x + initial_size, start_y + initial_size
            
            # Simple expansion algorithm
            threshold = np.std(edges) * 0.3
            
            # Expand left
            while x1 > 0 and np.mean(edges[y1:y2, x1-10:x1]) > threshold:
                x1 -= 10
            
            # Expand right  
            while x2 < width and np.mean(edges[y1:y2, x2:x2+10]) > threshold:
                x2 += 10
                
            # Expand up
            while y1 > 0 and np.mean(edges[y1-10:y1, x1:x2]) > threshold:
                y1 -= 10
                
            # Expand down
            while y2 < height and np.mean(edges[y2:y2+10, x1:x2]) > threshold:
                y2 += 10
            
            # Check if the region is large enough to be a figure
            if (x2 - x1) * (y2 - y1) > min_size * min_size:
                return (x1, y1, x2, y2)
            
            return None
            
        except Exception:
            return None
    
    def _overlaps_existing_figures(self, bbox, existing_figures):
        """Check if a bounding box overlaps significantly with existing figures"""
        x1, y1, x2, y2 = bbox
        area = (x2 - x1) * (y2 - y1)
        
        for existing_bbox in existing_figures:
            ex1, ey1, ex2, ey2 = existing_bbox
            
            # Calculate intersection
            ix1 = max(x1, ex1)
            iy1 = max(y1, ey1)
            ix2 = min(x2, ex2)
            iy2 = min(y2, ey2)
            
            if ix1 < ix2 and iy1 < iy2:
                intersection_area = (ix2 - ix1) * (iy2 - iy1)
                if intersection_area > area * 0.5:  # 50% overlap threshold
                    return True
        
        return False
    
    def _contains_diagram_elements(self, region_crop):
        """Check if a region contains actual diagram elements (boxes, lines, arrows)"""
        try:
            # Look for geometric patterns typical of diagrams
            height, width = region_crop.shape
            
            # Detect horizontal and vertical lines (common in diagrams)
            horizontal_kernel = np.ones((1, width//10))
            vertical_kernel = np.ones((height//10, 1))
            
            from scipy import ndimage
            horizontal_lines = ndimage.convolve(region_crop.astype(float), horizontal_kernel)
            vertical_lines = ndimage.convolve(region_crop.astype(float), vertical_kernel)
            
            # Check for strong line responses
            h_line_strength = np.max(horizontal_lines)
            v_line_strength = np.max(vertical_lines)
            
            # Look for rectangular regions (boxes in diagrams)
            edges = ndimage.sobel(region_crop)
            edge_strength = np.mean(edges > np.std(edges))
            
            # Check contrast variation (diagrams have clear boundaries)
            contrast = np.std(region_crop)
            
            # Diagrams typically have: strong lines, clear edges, good contrast
            has_lines = h_line_strength > np.std(region_crop) * 1.5 or v_line_strength > np.std(region_crop) * 1.5
            has_edges = edge_strength > 0.03  # Reduced threshold
            has_contrast = contrast > 20     # Reduced threshold
            
            return has_lines and has_edges and has_contrast
            
        except Exception:
            return False
    
    def _is_actual_diagram(self, img):
        """Final validation to ensure this is actually a diagram, not text"""
        try:
            # Convert to grayscale
            gray = np.array(img.convert('L'))
            height, width = gray.shape
            
            # For now, be very permissive - if it made it this far, it's likely a diagram
            # The earlier filters already removed most non-diagram content
            
            # Basic size check - diagrams should be substantial in size
            if width < 200 or height < 150:
                return False
            
            # Simple check for visual content vs pure text
            from scipy import ndimage
            edges = ndimage.sobel(gray)
            edge_strength = np.mean(edges > np.percentile(edges, 70))
            
            # Check for sufficient visual structure (not just text)
            has_visual_content = edge_strength > 0.05
            
            # Check for reasonable contrast (not just uniform color)
            contrast = np.std(gray)
            has_contrast = contrast > 20
            
            # Very permissive - if it has some visual structure and contrast, accept it
            return has_visual_content and has_contrast
            
        except Exception:
            return True  # If validation fails, err on the side of inclusion
    
    def extract_figures_to_folder(self, pdf_bytes: bytes, output_folder: str, max_pages: int = 100) -> List[Dict[str, Any]]:
        """Extract only figures/diagrams from PDF pages and save to folder (skips pages without figures)"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            total_pages = len(pdf_reader.pages)
            
            # Create output folder if it doesn't exist, or clear it if it does
            if os.path.exists(output_folder):
                # Remove existing images to avoid confusion
                for filename in os.listdir(output_folder):
                    if filename.endswith('.png'):
                        os.remove(os.path.join(output_folder, filename))
                print(f"Cleared existing figures from {output_folder}")
            else:
                os.makedirs(output_folder)
                print(f"Created new folder: {output_folder}")
            
            # Limit pages to process
            last_page = min(total_pages, max_pages)
            
            print(f"Analyzing {last_page} pages for figures...")
            
            # Convert PDF pages to images
            images = convert_from_bytes(
                pdf_bytes,
                dpi=self.image_quality,
                first_page=1,
                last_page=last_page
            )
            
            extracted_figures = []
            figure_count = 0
            
            for page_num, page_image in enumerate(images, 1):
                print(f"  Processing page {page_num}/{last_page}...", end="")
                
                # Detect figures in this page
                figures_in_page = self._detect_figures_in_image(page_image)
                
                if figures_in_page:
                    print(f" Found {len(figures_in_page)} figure(s)")
                    
                    for fig_idx, figure_data in enumerate(figures_in_page):
                        figure_count += 1
                        figure_filename = f"figure_{figure_count:03d}_page_{page_num:03d}_{fig_idx+1}.png"
                        figure_path = os.path.join(output_folder, figure_filename)
                        
                        # Save the figure
                        figure_data['image'].save(figure_path, format='PNG', optimize=True, quality=95)
                        
                        extracted_figures.append({
                            "figure_number": figure_count,
                            "page_number": page_num,
                            "figure_index_in_page": fig_idx + 1,
                            "image_path": figure_path,
                            "image_filename": figure_filename,
                            "width": figure_data['image'].width,
                            "height": figure_data['image'].height,
                            "format": "PNG",
                            "file_size_kb": os.path.getsize(figure_path) // 1024,
                            "bbox": figure_data['bbox'],
                            "confidence": figure_data['confidence']
                        })
                else:
                    print(" No figures detected, skipping")
                
                if page_num % 10 == 0:
                    print(f"  Progress: {page_num}/{last_page} pages processed, {figure_count} figures extracted so far")
            
            print(f"\nSuccessfully extracted {len(extracted_figures)} figures from {last_page} pages")
            print(f"Figures saved to: {output_folder}")
            
            return extracted_figures
            
        except Exception as e:
            print(f"Figure extraction failed: {str(e)}")
            return []
    
    def extract_pypdf_images(self, pdf_bytes: bytes, output_folder: str = None) -> List[Dict[str, Any]]:
        """Extract embedded images from PDF using PyPDF"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            
            if output_folder and not os.path.exists(output_folder):
                os.makedirs(output_folder)
            
            extracted_images = []
            image_count = 0
            
            print(f"Scanning {len(pdf_reader.pages)} pages for embedded images...")
            
            for page_num, page in enumerate(pdf_reader.pages, 1):
                print(f"  Page {page_num}: ", end="")
                
                try:
                    # Check if page has resources and XObject
                    if "/Resources" in page and "/XObject" in page["/Resources"]:
                        xObject = page["/Resources"]["/XObject"]
                        
                        page_images = []
                        for obj_name in xObject:
                            obj = xObject[obj_name]
                            
                            # Check if this is an image
                            if obj.get("/Subtype") == "/Image":
                                try:
                                    # Extract image data
                                    width = int(obj["/Width"])
                                    height = int(obj["/Height"])
                                    
                                    # Get image data
                                    data = obj.get_data()
                                    
                                    # Determine format based on filter
                                    image_format = "png"  # Default
                                    if "/Filter" in obj:
                                        filter_type = obj["/Filter"]
                                        if filter_type == "/DCTDecode":
                                            image_format = "jpg"
                                        elif filter_type == "/JPXDecode":
                                            image_format = "jp2"
                                        elif filter_type == "/CCITTFaxDecode":
                                            image_format = "tiff"
                                    
                                    image_count += 1
                                    image_name = f"pypdf_page{page_num}_{len(page_images)+1}.{image_format}"
                                    
                                    if output_folder:
                                        # Save to file
                                        image_path = os.path.join(output_folder, image_name)
                                        with open(image_path, "wb") as image_file:
                                            image_file.write(data)
                                        
                                        extracted_images.append({
                                            "image_number": image_count,
                                            "page_number": page_num,
                                            "image_index_in_page": len(page_images) + 1,
                                            "image_path": image_path,
                                            "image_filename": image_name,
                                            "width": width,
                                            "height": height,
                                            "format": image_format.upper(),
                                            "file_size_kb": len(data) // 1024,
                                            "object_name": str(obj_name)
                                        })
                                        
                                        page_images.append({
                                            "name": image_name,
                                            "size": f"{width}x{height}",
                                            "kb": len(data) // 1024
                                        })
                                    else:
                                        # Return base64 encoded
                                        img_base64 = base64.b64encode(data).decode()
                                        extracted_images.append({
                                            "image_number": image_count,
                                            "page_number": page_num,
                                            "image_index_in_page": len(page_images) + 1,
                                            "image_base64": img_base64,
                                            "width": width,
                                            "height": height,
                                            "format": image_format.upper(),
                                            "object_name": str(obj_name)
                                        })
                                        
                                        page_images.append({
                                            "size": f"{width}x{height}",
                                            "kb": len(data) // 1024
                                        })
                                        
                                except Exception as img_error:
                                    print(f"Error extracting image {obj_name}: {img_error}")
                        
                        if page_images:
                            imgs_desc = ", ".join([f"{img['name']} ({img['size']}, {img['kb']}KB)" for img in page_images])
                            print(f"Found {len(page_images)} image(s): {imgs_desc}")
                        else:
                            print("No images")
                    else:
                        print("No XObject resources")
                        
                except Exception as page_error:
                    print(f"Error processing page {page_num}: {page_error}")
            
            print(f"\nTotal images extracted: {len(extracted_images)}")
            if output_folder:
                print(f"Images saved to: {output_folder}")
            
            return extracted_images
            
        except Exception as e:
            print(f"PyPDF image extraction failed: {str(e)}")
            return []
    
    def extract_specific_figure_pypdf(self, pdf_bytes: bytes, figure_reference: str, output_folder: str = None) -> Dict[str, Any]:
        """Extract a specific figure using PyPDF method - find embedded images near the figure reference"""
        try:
            # First, find the figure reference in text
            text_result = self.extract_text_and_metadata(pdf_bytes)
            full_text = text_result['text']
            pages_text = text_result['pages']
            
            # Find the figure reference in the text
            target_page, context = self._find_figure_reference_in_text(figure_reference, pages_text, full_text)
            
            if target_page is None:
                print(f"Could not find reference to '{figure_reference}' in the document")
                return {"error": f"Figure reference '{figure_reference}' not found"}
            
            print(f"Found '{figure_reference}' reference on page {target_page}")
            print(f"Context: ...{context}...")
            
            # Search for embedded images on the target page and nearby pages
            search_pages = [target_page]
            if target_page > 1:
                search_pages.insert(0, target_page - 1)  # Previous page
            if target_page < len(pages_text):
                search_pages.append(target_page + 1)     # Next page
            
            print(f"Searching for embedded images on pages: {search_pages}")
            
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            
            if output_folder and not os.path.exists(output_folder):
                os.makedirs(output_folder)
            
            # Look for images on the target pages
            for page_num in search_pages:
                page_index = page_num - 1  # Convert to 0-based index
                if page_index >= len(pdf_reader.pages):
                    continue
                    
                print(f"  Checking page {page_num} for embedded images...")
                page = pdf_reader.pages[page_index]
                
                try:
                    if "/Resources" in page and "/XObject" in page["/Resources"]:
                        xObject = page["/Resources"]["/XObject"]
                        
                        best_image = None
                        best_size = 0
                        
                        for obj_name in xObject:
                            obj = xObject[obj_name]
                            
                            if obj.get("/Subtype") == "/Image":
                                try:
                                    width = int(obj["/Width"])
                                    height = int(obj["/Height"])
                                    size = width * height
                                    
                                    print(f"    Found image: {width}x{height} pixels")
                                    
                                    # Choose the largest image (most likely to be the figure)
                                    if size > best_size:
                                        best_size = size
                                        best_image = {
                                            "obj": obj,
                                            "obj_name": obj_name,
                                            "width": width,
                                            "height": height,
                                            "page_num": page_num
                                        }
                                        
                                except Exception as img_error:
                                    print(f"    Error processing image {obj_name}: {img_error}")
                        
                        if best_image:
                            # Extract the best image
                            obj = best_image["obj"]
                            data = obj.get_data()
                            width = best_image["width"]
                            height = best_image["height"]
                            
                            # Determine format
                            image_format = "png"
                            if "/Filter" in obj:
                                filter_type = obj["/Filter"]
                                if filter_type == "/DCTDecode":
                                    image_format = "jpg"
                                elif filter_type == "/JPXDecode":
                                    image_format = "jp2"
                            
                            # Clean the figure reference for filename
                            clean_ref = re.sub(r'[^\w\.]', '_', figure_reference.lower())
                            image_name = f"{clean_ref}_page_{page_num}.{image_format}"
                            
                            if output_folder:
                                # Save to file
                                image_path = os.path.join(output_folder, image_name)
                                with open(image_path, "wb") as image_file:
                                    image_file.write(data)
                                
                                return {
                                    "figure_reference": figure_reference,
                                    "found": True,
                                    "page_number": page_num,
                                    "image_path": image_path,
                                    "image_filename": image_name,
                                    "width": width,
                                    "height": height,
                                    "format": image_format.upper(),
                                    "file_size_kb": len(data) // 1024,
                                    "context": context,
                                    "object_name": str(best_image["obj_name"]),
                                    "extraction_method": "PyPDF_embedded"
                                }
                            else:
                                # Return base64
                                img_base64 = base64.b64encode(data).decode()
                                
                                return {
                                    "figure_reference": figure_reference,
                                    "found": True,
                                    "page_number": page_num,
                                    "image_base64": img_base64,
                                    "width": width,
                                    "height": height,
                                    "format": image_format.upper(),
                                    "context": context,
                                    "object_name": str(best_image["obj_name"]),
                                    "extraction_method": "PyPDF_embedded"
                                }
                        else:
                            print(f"    No images found on page {page_num}")
                    else:
                        print(f"    No XObject resources on page {page_num}")
                        
                except Exception as page_error:
                    print(f"    Error processing page {page_num}: {page_error}")
            
            return {"error": f"No embedded images found near '{figure_reference}' on pages {search_pages}"}
            
        except Exception as e:
            print(f"PyPDF figure extraction failed: {str(e)}")
            return {"error": str(e)}
    
    def extract_specific_figure(self, pdf_bytes: bytes, figure_reference: str, output_folder: str = None) -> Dict[str, Any]:
        """Extract a specific figure by reference (e.g., 'Figure 1.1') using fuzzy matching"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            total_pages = len(pdf_reader.pages)
            
            # First, find the text and locate the figure reference
            text_result = self.extract_text_and_metadata(pdf_bytes)
            full_text = text_result['text']
            pages_text = text_result['pages']
            
            # Find the figure reference in the text with fuzzy matching
            target_page, context = self._find_figure_reference_in_text(figure_reference, pages_text, full_text)
            
            if target_page is None:
                print(f"Could not find reference to '{figure_reference}' in the document")
                return {"error": f"Figure reference '{figure_reference}' not found"}
            
            print(f"Found '{figure_reference}' reference on page {target_page}")
            print(f"Context: ...{context}...")
            
            # Search for the figure on the target page and nearby pages
            search_pages = [target_page]
            if target_page > 1:
                search_pages.insert(0, target_page - 1)  # Previous page
            if target_page < total_pages:
                search_pages.append(target_page + 1)     # Next page
            
            print(f"Searching for figure on pages: {search_pages}")
            
            # Convert relevant pages to images
            for page_num in search_pages:
                print(f"  Analyzing page {page_num} for '{figure_reference}'...")
                
                # Convert single page to image
                page_images = convert_from_bytes(
                    pdf_bytes,
                    dpi=self.image_quality,
                    first_page=page_num,
                    last_page=page_num
                )
                
                if not page_images:
                    continue
                
                page_image = page_images[0]
                
                # Look for figures on this page
                figures_on_page = self._detect_figures_in_image(page_image)
                
                if figures_on_page:
                    print(f"    Found {len(figures_on_page)} potential figure(s) on page {page_num}")
                    
                    # For now, take the first/best figure found on the target page
                    # In the future, we could add more sophisticated matching
                    best_figure = figures_on_page[0]  # Take the first one
                    
                    # Save the figure if output folder is specified
                    if output_folder:
                        if not os.path.exists(output_folder):
                            os.makedirs(output_folder)
                        
                        # Clean the figure reference for filename
                        clean_ref = re.sub(r'[^\w\.]', '_', figure_reference.lower())
                        figure_filename = f"{clean_ref}_page_{page_num}.png"
                        figure_path = os.path.join(output_folder, figure_filename)
                        
                        best_figure['image'].save(figure_path, format='PNG', optimize=True, quality=95)
                        
                        result = {
                            "figure_reference": figure_reference,
                            "found": True,
                            "page_number": page_num,
                            "image_path": figure_path,
                            "image_filename": figure_filename,
                            "width": best_figure['image'].width,
                            "height": best_figure['image'].height,
                            "bbox": best_figure['bbox'],
                            "confidence": best_figure['confidence'],
                            "context": context,
                            "file_size_kb": os.path.getsize(figure_path) // 1024
                        }
                    else:
                        # Convert to base64 if no output folder
                        img_buffer = io.BytesIO()
                        best_figure['image'].save(img_buffer, format='PNG', optimize=True, quality=95)
                        img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
                        
                        result = {
                            "figure_reference": figure_reference,
                            "found": True,
                            "page_number": page_num,
                            "image_base64": img_base64,
                            "width": best_figure['image'].width,
                            "height": best_figure['image'].height,
                            "bbox": best_figure['bbox'],
                            "confidence": best_figure['confidence'],
                            "context": context
                        }
                    
                    print(f"    Successfully extracted '{figure_reference}' from page {page_num}")
                    return result
                else:
                    print(f"    No figures detected on page {page_num}")
            
            return {"error": f"Could not find figure '{figure_reference}' on expected pages", "searched_pages": search_pages}
            
        except Exception as e:
            print(f"Specific figure extraction failed: {str(e)}")
            return {"error": str(e)}
    
    def _find_figure_reference_in_text(self, figure_reference: str, pages_text: List[Dict], full_text: str) -> Tuple[int, str]:
        """Find a figure reference in the text using fuzzy matching and return page number and context"""
        import re
        from difflib import SequenceMatcher
        
        # Normalize the figure reference for matching
        normalized_ref = re.sub(r'\s+', r'\\s+', figure_reference.strip())
        
        # Try exact match first
        pattern = rf'\b{re.escape(figure_reference)}\b'
        match = re.search(pattern, full_text, re.IGNORECASE)
        
        if match:
            # Found exact match, find which page it's on
            match_pos = match.start()
            return self._find_page_for_position(match_pos, pages_text, match.group())
        
        # Try fuzzy matching with common variations
        variations = [
            figure_reference,
            figure_reference.replace('Figure', 'Fig'),
            figure_reference.replace('Fig', 'Figure'),
            figure_reference.replace('.', ''),
            figure_reference.replace(' ', ''),
        ]
        
        best_match = None
        best_ratio = 0.7  # Minimum similarity threshold
        
        for page_data in pages_text:
            page_text = page_data.get('text', '')
            page_num = page_data.get('page_number', 0)
            
            for variation in variations:
                # Look for the variation in the page
                pattern = rf'\b{re.escape(variation)}\b'
                matches = re.finditer(pattern, page_text, re.IGNORECASE)
                
                for match in matches:
                    # Calculate similarity
                    ratio = SequenceMatcher(None, figure_reference.lower(), match.group().lower()).ratio()
                    if ratio > best_ratio:
                        best_ratio = ratio
                        best_match = (page_num, match.group(), match.start(), match.end())
        
        if best_match:
            page_num, matched_text, start, end = best_match
            # Get context around the match
            page_text = next(p['text'] for p in pages_text if p['page_number'] == page_num)
            context_start = max(0, start - 50)
            context_end = min(len(page_text), end + 50)
            context = page_text[context_start:context_end].strip()
            return page_num, context
        
        return None, ""
    
    def _find_page_for_position(self, position: int, pages_text: List[Dict], matched_text: str) -> Tuple[int, str]:
        """Find which page contains a specific character position in the full text"""
        current_pos = 0
        
        for page_data in pages_text:
            page_text = page_data.get('text', '')
            page_num = page_data.get('page_number', 0)
            
            if current_pos <= position < current_pos + len(page_text):
                # This page contains the position
                relative_pos = position - current_pos
                context_start = max(0, relative_pos - 50)
                context_end = min(len(page_text), relative_pos + len(matched_text) + 50)
                context = page_text[context_start:context_end].strip()
                return page_num, context
            
            current_pos += len(page_text) + 2  # +2 for the "\n\n" separator
        
        return 1, matched_text  # Fallback to first page
    
    def detect_visual_elements(self, pdf_bytes: bytes) -> List[Dict[str, Any]]:
        """Detect and extract graphs, tables, and diagrams"""
        # This is a simplified version - in production you'd use
        # more sophisticated image analysis or ML models
        try:
            images = self.extract_images(pdf_bytes, max_images=10)
            visual_elements = []
            
            for img_data in images:
                # Simple heuristics to identify potential visual elements
                # In practice, you'd use ML models or computer vision
                width, height = img_data["width"], img_data["height"]
                aspect_ratio = width / height if height > 0 else 1
                
                # Heuristic classification
                element_type = "page_image"
                if aspect_ratio > 1.5:
                    element_type = "potential_chart"
                elif 0.7 <= aspect_ratio <= 1.3:
                    element_type = "potential_diagram"
                
                visual_elements.append({
                    "page_number": img_data["page_number"],
                    "element_type": element_type,
                    "image_base64": img_data["image_base64"],
                    "width": width,
                    "height": height,
                    "confidence": 0.5  # Placeholder confidence score
                })
            
            return visual_elements
            
        except Exception as e:
            print(f"Visual element detection failed: {str(e)}")
            return []  # Return empty list instead of raising exception
    
    def analyze_document_structure(self, text_data: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze document structure to identify sections, chapters, etc."""
        full_text = text_data["text"]
        pages = text_data["pages"]
        
        # Simple structure detection
        structure = {
            "has_table_of_contents": False,
            "has_bibliography": False,
            "has_chapters": False,
            "estimated_sections": [],
            "document_length": "unknown"
        }
        
        # Check for table of contents
        if any(keyword in full_text.lower() for keyword in ["table of contents", "contents"]):
            structure["has_table_of_contents"] = True
        
        # Check for bibliography/references
        if any(keyword in full_text.lower() for keyword in ["bibliography", "references", "works cited"]):
            structure["has_bibliography"] = True
        
        # Check for chapters
        chapter_indicators = ["chapter", "chapter 1", "chapter i"]
        if any(indicator in full_text.lower() for indicator in chapter_indicators):
            structure["has_chapters"] = True
        
        # Estimate document length category
        word_count = text_data["total_words"]
        if word_count < 1000:
            structure["document_length"] = "short"
        elif word_count < 10000:
            structure["document_length"] = "medium"
        else:
            structure["document_length"] = "long"
        
        return structure

    def extract_figure_by_caption(self, pdf_bytes: bytes, figure_reference: str, output_folder: str = None, page_hint: Optional[int] = None) -> Dict[str, Any]:
        """Extract figure using caption-based spatial reasoning with PyMuPDF"""
        try:
            # Open PDF with PyMuPDF
            doc = fitz.open(stream=pdf_bytes, filetype="pdf")
            
            # Search through pages
            if page_hint is not None:
                pages_to_search = [(page_hint - 1, doc[page_hint - 1])]  # Convert 1-based to 0-based
            else:
                pages_to_search = list(enumerate(doc))
            
            for page_idx, page in pages_to_search:
                # Search for the actual figure caption (not in-text citations)
                # Look for patterns that indicate this is a caption, not a citation
                base_number = figure_reference.split()[-1]  # Extract "1.1" from "Figure 1.1"
                caption_variations = [
                    f"{figure_reference}:",  # "Figure 2.1:"
                    f"{figure_reference.replace('Figure', 'Fig')}:",  # "Fig 2.1:"
                    f"{figure_reference.replace('Figure', 'Fig.')}:",  # "Fig. 2.1:"
                    figure_reference,  # "Figure 2.1" (without colon)
                    figure_reference.replace('Figure', 'Fig'),  # "Fig 2.1"
                    figure_reference.replace('Figure', 'Fig.'),  # "Fig. 2.1"
                ]
                
                found_bbox = None
                found_caption = None
                
                # Try a different approach: look for the actual figure caption block
                # This searches for the figure number at the beginning of lines with substantial text
                full_page_text = page.get_text()
                lines = full_page_text.split('\n')
                
                for line_idx, line in enumerate(lines):
                    line_clean = line.strip()
                    
                    # Check if this line starts with our figure reference
                    for caption in caption_variations:
                        if line_clean.lower().startswith(caption.lower()):
                            # This might be a caption line - check if it has descriptive content
                            caption_text = line_clean[len(caption):].strip()
                            
                            # Look at next few lines too (captions often span multiple lines)
                            full_caption_text = caption_text
                            for next_line_idx in range(line_idx + 1, min(line_idx + 4, len(lines))):
                                next_line = lines[next_line_idx].strip()
                                if len(next_line) > 0 and not next_line.lower().startswith(('figure', 'fig', 'table')):
                                    full_caption_text += " " + next_line
                                else:
                                    break
                            
                            print(f"Checking line starting with '{caption}': '{full_caption_text[:80]}...'")
                            
                            # Check if this looks like a real caption (has substantial descriptive text)
                            caption_words = full_caption_text.lower().split()
                            
                            # Strong indicators this is a real caption
                            caption_indicators = [
                                "classification", "algorithm", "training", "data", "model", 
                                "system", "process", "method", "approach", "technique",
                                "shows", "illustrates", "demonstrates", "depicts", "presents",
                                "using", "with", "by", "points", "two-dimensional", "features",
                                "nearest", "neighbors", "class", "probabilities", "functions",
                                "conceptual", "view", "ecosystem", "regression", "estimating"
                            ]
                            
                            # Strong indicators this is an in-text citation
                            citation_indicators = [
                                "illustrated in", "shown in", "see", "as in", "depicted in",
                                "presented in", "given in", "described in", "refer to"
                            ]
                            
                            has_caption_indicators = any(indicator in full_caption_text.lower() for indicator in caption_indicators)
                            has_citation_indicators = any(indicator in full_caption_text.lower() for indicator in citation_indicators)
                            has_substantial_text = len(caption_words) >= 5
                            has_descriptive_punctuation = ":" in full_caption_text or "." in full_caption_text
                            
                            is_real_caption = (
                                has_caption_indicators or 
                                (has_substantial_text and has_descriptive_punctuation)
                            ) and not has_citation_indicators
                            
                            print(f"  Caption indicators: {has_caption_indicators}")
                            print(f"  Citation indicators: {has_citation_indicators}")  
                            print(f"  Substantial text: {has_substantial_text}")
                            print(f"  Is real caption: {is_real_caption}")
                            
                            if is_real_caption:
                                # Find this text on the page to get its bounding box
                                search_text = line_clean[:min(50, len(line_clean))]  # First 50 chars
                                bboxes = page.search_for(search_text, quads=True)
                                
                                if bboxes:
                                    print(f"Found real caption '{caption}' on page {page_idx + 1}")
                                    print(f"Caption content: {full_caption_text[:100]}...")
                                    
                                    # Convert quads to rects and merge them
                                    found_bbox = bboxes[0].rect
                                    for b in bboxes[1:]:
                                        found_bbox |= b.rect
                                    
                                    found_caption = caption
                                    break
                    
                    if found_bbox:
                        break
                
                if not found_bbox:
                    continue
                
                print(f"Caption bounding box: {found_bbox}")
                
                # Get all words on the page
                words = page.get_text("words")
                print(f"Found {len(words)} words on page")
                
                # Walk upward from caption until we hit other text blocks
                y0 = found_bbox.y0
                original_y0 = y0
                
                # More aggressive expansion - go up further looking for figure content
                expansion_step = 5  # Larger steps
                min_figure_height = 50  # Minimum expected figure height
                
                while y0 > 0:
                    # Check if there are any words between current y0 and original caption position
                    words_in_between = [w for w in words if y0 < w[3] < (original_y0 - 5)]  # w[3] is bottom y, with buffer
                    if words_in_between and (original_y0 - y0) > min_figure_height:
                        print(f"Found text at y={y0}, stopping expansion (expanded by {original_y0 - y0:.1f} points)")
                        break
                    y0 -= expansion_step
                
                # Ensure minimum figure height
                if (original_y0 - y0) < min_figure_height:
                    y0 = original_y0 - min_figure_height
                    print(f"Applied minimum figure height: {min_figure_height} points")
                
                # Expand horizontally to capture wider figures and full captions
                # Use more generous horizontal padding, especially to the right for captions
                left_padding = max(20, (found_bbox.x1 - found_bbox.x0) * 0.3)
                right_padding = max(50, (found_bbox.x1 - found_bbox.x0) * 1.0)  # More generous right padding
                y_padding = 15
                
                # Create the figure rectangle with expanded bounds
                fig_rect = fitz.Rect(
                    max(0, found_bbox.x0 - left_padding),  # Don't go beyond page bounds
                    max(0, y0),
                    min(page.rect.width, found_bbox.x1 + right_padding),  # Extend more to the right
                    found_bbox.y1 + y_padding
                )
                
                print(f"Figure rectangle: {fig_rect}")
                print(f"Figure dimensions: {fig_rect.width} x {fig_rect.height}")
                
                # Render the figure region at high resolution
                matrix = fitz.Matrix(2, 2)  # 144 DPI (2x scaling)
                pix = page.get_pixmap(matrix=matrix, clip=fig_rect)
                
                # Convert to PIL Image
                img_data = pix.tobytes()
                figure_image = Image.open(io.BytesIO(img_data))
                
                # Create output folder if specified
                if output_folder:
                    os.makedirs(output_folder, exist_ok=True)
                    # Clear existing files for this figure
                    safe_ref = figure_reference.replace(" ", "_").replace(".", "_")
                    for file in os.listdir(output_folder):
                        if file.startswith(safe_ref):
                            os.remove(os.path.join(output_folder, file))
                
                # Save the extracted figure
                safe_ref = figure_reference.replace(" ", "_").replace(".", "_")
                filename = f"{safe_ref}_caption_method_page_{page_idx + 1}_{int(fig_rect.width)}x{int(fig_rect.height)}.png"
                
                if output_folder:
                    filepath = os.path.join(output_folder, filename)
                    figure_image.save(filepath, "PNG", optimize=True)
                    print(f"Saved figure to: {filepath}")
                
                # Convert to base64 for API response
                img_buffer = io.BytesIO()
                figure_image.save(img_buffer, format='PNG')
                img_data = img_buffer.getvalue()
                
                doc.close()
                
                return {
                    "page_number": page_idx + 1,
                    "image_filename": filename,
                    "width": int(fig_rect.width * 2),  # Account for 2x matrix scaling
                    "height": int(fig_rect.height * 2),
                    "format": "png",
                    "file_size_kb": len(img_data) // 1024,
                    "figure_reference": figure_reference,
                    "caption_found": found_caption,
                    "caption_bbox": [found_bbox.x0, found_bbox.y0, found_bbox.x1, found_bbox.y1],
                    "figure_bbox": [fig_rect.x0, fig_rect.y0, fig_rect.x1, fig_rect.y1],
                    "extraction_method": "caption_spatial_reasoning",
                    "image_data": base64.b64encode(img_data).decode() if not output_folder else None
                }
            
            doc.close()
            return {"error": f"Caption '{figure_reference}' not found in PDF"}
            
        except Exception as e:
            import traceback
            print(f"Error in extract_figure_by_caption: {e}")
            traceback.print_exc()
            return {"error": f"Error extracting figure: {e}"}

    def extract_figure_from_page_image(self, pdf_bytes: bytes, figure_reference: str, output_folder: str = None) -> Dict[str, Any]:
        """Extract figure by converting PDF page to image and detecting figure region"""
        try:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(pdf_bytes))
            
            # First, find the figure reference in the text
            text_result = self.extract_text_and_metadata(pdf_bytes)
            pages_text = text_result['pages']
            full_text = text_result['text']
            
            # Find the figure reference
            target_page, context = self._find_figure_reference_in_text(figure_reference, pages_text, full_text)
            
            if target_page is None:
                return {"error": f"Could not find '{figure_reference}' in PDF text"}
            
            print(f"Found '{figure_reference}' reference on page {target_page}")
            print(f"Context: ...{context}...")
            
            # Create output folder if specified
            if output_folder:
                os.makedirs(output_folder, exist_ok=True)
                # Clear existing files for this figure
                safe_ref = figure_reference.replace(" ", "_").replace(".", "_")
                for file in os.listdir(output_folder):
                    if file.startswith(safe_ref):
                        os.remove(os.path.join(output_folder, file))
            
            # Convert the specific page to high-resolution image
            print(f"Converting page {target_page} to image...")
            page_images = convert_from_bytes(
                pdf_bytes, 
                dpi=self.image_quality,
                first_page=target_page,
                last_page=target_page
            )
            
            if not page_images:
                return {"error": f"Could not convert page {target_page} to image"}
            
            page_image = page_images[0]
            page_array = np.array(page_image)
            
            # Detect figure region using computer vision
            figure_bbox = self._detect_figure_region(page_array, figure_reference)
            
            if figure_bbox is None:
                return {"error": f"Could not detect figure region for '{figure_reference}' on page {target_page}"}
            
            # Crop the detected figure region
            x, y, w, h = figure_bbox
            figure_image = page_image.crop((x, y, x + w, y + h))
            
            # Save the extracted figure
            safe_ref = figure_reference.replace(" ", "_").replace(".", "_")
            filename = f"{safe_ref}_page_{target_page}_{w}x{h}.png"
            
            if output_folder:
                filepath = os.path.join(output_folder, filename)
                figure_image.save(filepath, "PNG", optimize=True)
                print(f"Saved figure to: {filepath}")
            
            # Convert to base64 for API response
            img_buffer = io.BytesIO()
            figure_image.save(img_buffer, format='PNG')
            img_data = img_buffer.getvalue()
            
            return {
                "page_number": target_page,
                "image_filename": filename,
                "width": w,
                "height": h,
                "format": "png",
                "file_size_kb": len(img_data) // 1024,
                "figure_reference": figure_reference,
                "context": context,
                "bbox": figure_bbox,
                "image_data": base64.b64encode(img_data).decode() if not output_folder else None
            }
            
        except Exception as e:
            import traceback
            print(f"Error in extract_figure_from_page_image: {e}")
            traceback.print_exc()
            return {"error": f"Error extracting figure: {e}"}

    def _detect_figure_region(self, page_array: np.ndarray, figure_reference: str) -> Tuple[int, int, int, int]:
        """Detect figure region in page image using computer vision"""
        try:
            # Convert to grayscale
            if len(page_array.shape) == 3:
                gray = np.mean(page_array, axis=2).astype(np.uint8)
            else:
                gray = page_array
            
            print(f"Page image size: {gray.shape}")
            
            # Apply median filter to reduce noise
            gray = ndimage.median_filter(gray, size=3)
            
            # Create binary image - figures typically have darker content
            # Use adaptive threshold based on local mean
            kernel_size = 20
            local_mean = ndimage.uniform_filter(gray.astype(float), size=kernel_size)
            binary = gray < (local_mean - 5)  # More permissive threshold
            
            # Morphological operations to clean up
            # Remove small noise
            binary = binary_erosion(binary, iterations=1)
            binary = binary_dilation(binary, iterations=3)  # More dilation
            
            # Find connected components
            labeled, num_features = ndimage.label(binary)
            
            print(f"Found {num_features} connected components")
            
            if num_features == 0:
                return None
            
            # Find component properties
            component_props = []
            total_pixels = gray.shape[0] * gray.shape[1]
            
            for i in range(1, num_features + 1):
                component_mask = (labeled == i)
                component_area = np.sum(component_mask)
                
                # Get bounding box first
                rows, cols = np.where(component_mask)
                if len(rows) == 0 or len(cols) == 0:
                    continue
                    
                min_row, max_row = np.min(rows), np.max(rows)
                min_col, max_col = np.min(cols), np.max(cols)
                
                width = max_col - min_col + 1
                height = max_row - min_row + 1
                
                # More permissive filters
                area_ratio = component_area / total_pixels
                aspect_ratio = width / height if height > 0 else 0
                
                print(f"  Component {i}: area={area_ratio:.4f}, aspect={aspect_ratio:.2f}, size={width}x{height}")
                
                # Skip very small or very large components (more permissive)
                if area_ratio < 0.0005:  # Too small (< 0.05% of page)
                    print(f"    Skipped: too small")
                    continue
                if area_ratio > 0.6:    # Too large (> 60% of page)
                    print(f"    Skipped: too large")
                    continue
                
                # More permissive aspect ratio filter
                if aspect_ratio < 0.1 or aspect_ratio > 10:  # Very extreme aspect ratios
                    print(f"    Skipped: extreme aspect ratio")
                    continue
                
                # Prefer components that are more centrally located and reasonably sized
                center_x = (min_col + max_col) / 2
                center_y = (min_row + max_row) / 2
                page_center_x = gray.shape[1] / 2
                page_center_y = gray.shape[0] / 2
                
                # Distance from page center (normalized)
                center_distance = np.sqrt(
                    ((center_x - page_center_x) / page_center_x) ** 2 +
                    ((center_y - page_center_y) / page_center_y) ** 2
                )
                
                # Score based on size, aspect ratio, and position
                size_score = min(area_ratio / 0.05, 1.0)  # Prefer larger up to 5% of page
                aspect_score = 1.0 - abs(aspect_ratio - 1.5) / 3.0  # More permissive aspect score
                position_score = 1.0 - min(center_distance, 1.0)  # Prefer more central positions
                
                total_score = size_score * 0.5 + aspect_score * 0.2 + position_score * 0.3
                
                print(f"    Score: {total_score:.3f} (size={size_score:.3f}, aspect={aspect_score:.3f}, pos={position_score:.3f})")
                
                component_props.append({
                    'bbox': (min_col, min_row, width, height),
                    'area': component_area,
                    'area_ratio': area_ratio,
                    'aspect_ratio': aspect_ratio,
                    'score': total_score,
                    'center_distance': center_distance
                })
            
            if not component_props:
                print("No suitable components found")
                return None
            
            # Sort by score and return the best candidate
            component_props.sort(key=lambda x: x['score'], reverse=True)
            best_component = component_props[0]
            
            print(f"Best component: {best_component['bbox']} (score: {best_component['score']:.3f}, area: {best_component['area_ratio']:.4f})")
            return best_component['bbox']
            
        except Exception as e:
            print(f"Error in _detect_figure_region: {e}")
            import traceback
            traceback.print_exc()
            return None