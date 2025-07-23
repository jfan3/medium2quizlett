#!/usr/bin/env python3

import os
from PIL import Image

def check_extracted_figures():
    figures_folder = "/Users/jfan/Documents/models/medium2quizlett/knowledge-graph-api/specific_figures"
    
    if not os.path.exists(figures_folder):
        print("No figures folder found")
        return
    
    figure_files = [f for f in os.listdir(figures_folder) if f.endswith('.png')]
    
    print(f"Found {len(figure_files)} extracted figures:")
    print("="*50)
    
    for filename in sorted(figure_files):
        filepath = os.path.join(figures_folder, filename)
        
        try:
            img = Image.open(filepath)
            file_size = os.path.getsize(filepath)
            
            print(f"\n📄 {filename}")
            print(f"   Size: {img.width}x{img.height} pixels")
            print(f"   File size: {file_size} bytes ({file_size//1024} KB)")
            print(f"   Mode: {img.mode}")
            
            # For Figure 1.1, provide more details
            if "figure_1.1" in filename.lower():
                print(f"   ⭐ This should be the algorithmic marketing flowchart")
                print(f"   Expected: Boxes with 'Marketing System', 'Business Actions', arrows, etc.")
                
        except Exception as e:
            print(f"Error reading {filename}: {e}")

if __name__ == "__main__":
    check_extracted_figures()