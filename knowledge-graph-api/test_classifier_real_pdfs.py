#!/usr/bin/env python3

import os
from app.services.pdf_processor import PDFProcessor
from app.services.document_classifier import DocumentClassifier

def test_document_classifier():
    pdf_processor = PDFProcessor()
    classifier = DocumentClassifier()
    
    uploads_folder = "/Users/jfan/Documents/models/medium2quizlett/knowledge-graph-api/uploads"
    
    print(f"{'='*80}")
    print(f"TESTING DOCUMENT CLASSIFIER ON REAL PDFs")
    print(f"{'='*80}")
    
    # Get all PDF files in uploads folder
    pdf_files = [f for f in os.listdir(uploads_folder) if f.endswith('.pdf')]
    
    if not pdf_files:
        print("No PDF files found in uploads folder!")
        return
    
    print(f"Found {len(pdf_files)} PDF files to classify:")
    for pdf_file in pdf_files:
        print(f"  - {pdf_file}")
    
    for pdf_file in pdf_files:
        pdf_path = os.path.join(uploads_folder, pdf_file)
        
        print(f"\n{'='*60}")
        print(f"CLASSIFYING: {pdf_file}")
        print(f"{'='*60}")
        
        try:
            with open(pdf_path, 'rb') as f:
                pdf_bytes = f.read()
            
            # Extract text and metadata first
            text_data = pdf_processor.extract_text_and_metadata(pdf_bytes)
            
            # Create processing result format expected by classifier
            processing_result = {
                "text_content": text_data.get("text", ""),
                "metadata": {
                    "num_pages": text_data.get("num_pages", 0),
                    "title": text_data.get("title", ""),
                    "author": text_data.get("author", ""),
                    "creator": text_data.get("creator", "")
                },
                "visual_elements": []  # Skip visual elements for now as requested
            }
            
            # Classify document
            doc_type, confidence, details = classifier.classify_document(processing_result)
            
            print(f"📄 Document Info:")
            print(f"   Title: {text_data.get('title') or 'Not found'}")
            print(f"   Author: {text_data.get('author') or 'Not found'}")
            print(f"   Pages: {text_data.get('num_pages', 0)}")
            print(f"   Total words: {text_data.get('total_words', 0):,}")
            
            print(f"\n🔍 Classification Result:")
            print(f"   Document Type: {doc_type}")
            print(f"   Confidence: {confidence:.2f}")
            print(f"   Reasoning: {details['reasoning']}")
            
            print(f"\n📊 Classification Scores:")
            for doc_type_name, score in details['scores'].items():
                print(f"   {doc_type_name}: {score:.3f}")
            
            print(f"\n🔬 Features Detected:")
            features = details['features']
            print(f"   Word count: {features['word_count']:,}")
            print(f"   Page count: {features['page_count']}")
            print(f"   Has chapters: {features['has_chapters']}")
            print(f"   Has abstract: {features['has_abstract']}")
            print(f"   Has ToC: {features['has_toc']}")
            print(f"   Has bibliography: {features['has_bibliography']}")
            print(f"   Section count: {features['section_count']}")
            print(f"   Academic keywords: {features['academic_keywords']}")
            print(f"   Textbook keywords: {features['textbook_keywords']}")
            print(f"   Technical keywords: {features['technical_keywords']}")
            print(f"   Blog/Tutorial keywords: {features['blog_tutorial_keywords']}")
            print(f"   Tech Blog keywords: {features['tech_blog_keywords']}")
            print(f"   AI Generated keywords: {features['ai_generated_keywords']}")
            print(f"   Citations: {features['citation_count']}")
            print(f"   Avg sentence length: {features['average_sentence_length']:.1f}")
            
            # Show some sample content
            if text_data.get('text'):
                first_page_text = text_data['text'][:300]
                print(f"\n📖 First 300 characters:")
                print(f"   {first_page_text}...")
            
        except Exception as e:
            print(f"❌ Error processing {pdf_file}: {str(e)}")
            import traceback
            traceback.print_exc()
    
    print(f"\n{'='*80}")
    print(f"DOCUMENT CLASSIFICATION COMPLETE")
    print(f"{'='*80}")

if __name__ == "__main__":
    test_document_classifier()