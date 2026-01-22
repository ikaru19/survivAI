#!/usr/bin/env python3
"""
Generate a basic knowledge database without embeddings for testing.
This allows the app to work immediately without needing sentence-transformers.
"""

import json
import sqlite3
import sys
from pathlib import Path


def load_knowledge_files(knowledge_dir: Path):
    """Load all JSON knowledge files from the directory."""
    all_scenarios = []
    
    json_files = list(knowledge_dir.glob("*.json"))
    if not json_files:
        print(f"Warning: No JSON files found in {knowledge_dir}")
        return all_scenarios
    
    for json_file in json_files:
        print(f"Loading {json_file.name}...")
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                category = data.get('category', 'unknown')
                scenarios = data.get('scenarios', [])
                
                for scenario in scenarios:
                    scenario['category'] = category
                    all_scenarios.append(scenario)
                
                print(f"  Loaded {len(scenarios)} scenarios from {category}")
        except Exception as e:
            print(f"Error loading {json_file}: {e}")
            continue
    
    return all_scenarios


def create_database(db_path: Path, scenarios):
    """Create SQLite database without embeddings (for immediate testing)."""
    
    if db_path.exists():
        print(f"Removing existing database: {db_path}")
        db_path.unlink()
    
    print(f"Creating database: {db_path}")
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # Create main knowledge table (without embedding column for now)
    cursor.execute('''
        CREATE TABLE knowledge (
            id TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            keywords TEXT NOT NULL,
            context TEXT NOT NULL,
            priority TEXT NOT NULL,
            embedding BLOB
        )
    ''')
    
    # Create FTS5 virtual table for full-text search
    cursor.execute('''
        CREATE VIRTUAL TABLE knowledge_fts USING fts5(
            id,
            category,
            keywords,
            context,
            content=knowledge,
            content_rowid=rowid
        )
    ''')
    
    # Create triggers
    cursor.execute('''
        CREATE TRIGGER knowledge_ai AFTER INSERT ON knowledge BEGIN
            INSERT INTO knowledge_fts(rowid, id, category, keywords, context)
            VALUES (new.rowid, new.id, new.category, new.keywords, new.context);
        END
    ''')
    
    cursor.execute('''
        CREATE TRIGGER knowledge_ad AFTER DELETE ON knowledge BEGIN
            DELETE FROM knowledge_fts WHERE rowid = old.rowid;
        END
    ''')
    
    cursor.execute('''
        CREATE TRIGGER knowledge_au AFTER UPDATE ON knowledge BEGIN
            UPDATE knowledge_fts
            SET id = new.id,
                category = new.category,
                keywords = new.keywords,
                context = new.context
            WHERE rowid = old.rowid;
        END
    ''')
    
    # Create indexes
    cursor.execute('CREATE INDEX idx_category ON knowledge(category)')
    cursor.execute('CREATE INDEX idx_priority ON knowledge(priority)')
    
    print(f"Inserting {len(scenarios)} scenarios...")
    
    # Insert data (with NULL for embedding for now)
    for i, scenario in enumerate(scenarios, 1):
        scenario_id = scenario['id']
        category = scenario['category']
        keywords = ', '.join(scenario['keywords'])
        context = scenario['context']
        priority = scenario['priority']
        
        cursor.execute('''
            INSERT INTO knowledge (id, category, keywords, context, priority, embedding)
            VALUES (?, ?, ?, ?, ?, NULL)
        ''', (scenario_id, category, keywords, context, priority))
        
        if i % 10 == 0:
            print(f"  Processed {i}/{len(scenarios)} scenarios...")
    
    # Create metadata table
    cursor.execute('''
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    ''')
    
    cursor.execute('''
        INSERT INTO metadata (key, value) VALUES
        ('model_name', 'keyword-only'),
        ('embedding_dim', '0'),
        ('version', '1.0-basic'),
        ('total_scenarios', ?)
    ''', (str(len(scenarios)),))
    
    conn.commit()
    conn.close()
    
    print(f"✓ Database created successfully with {len(scenarios)} scenarios")
    print(f"✓ Location: {db_path}")
    print("\nNote: This is a basic version without embeddings.")
    print("The app will use keyword-based search only.")


def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    knowledge_dir = project_root / "survivAI" / "Resources" / "EmergencyKnowledge"
    output_db = project_root / "survivAI" / "Resources" / "emergency_knowledge.db"
    
    print("=" * 60)
    print("Emergency Knowledge Base - Basic Generator (No Embeddings)")
    print("=" * 60)
    print(f"Project root: {project_root}")
    print(f"Knowledge dir: {knowledge_dir}")
    print(f"Output database: {output_db}")
    print()
    
    if not knowledge_dir.exists():
        print(f"Error: Knowledge directory not found: {knowledge_dir}")
        sys.exit(1)
    
    scenarios = load_knowledge_files(knowledge_dir)
    if not scenarios:
        print("Error: No scenarios loaded")
        sys.exit(1)
    
    print(f"\nTotal scenarios loaded: {len(scenarios)}")
    
    output_db.parent.mkdir(parents=True, exist_ok=True)
    create_database(output_db, scenarios)
    
    print("\nVerifying database...")
    conn = sqlite3.connect(str(output_db))
    cursor = conn.cursor()
    
    cursor.execute('SELECT COUNT(*) FROM knowledge')
    count = cursor.fetchone()[0]
    print(f"✓ Database contains {count} knowledge entries")
    
    cursor.execute('SELECT key, value FROM metadata')
    metadata = dict(cursor.fetchall())
    print(f"✓ Model: {metadata.get('model_name', 'unknown')}")
    print(f"✓ Version: {metadata.get('version', 'unknown')}")
    
    conn.close()
    
    print("\n" + "=" * 60)
    print("✓ Database generation complete!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Add the generated .db file to your Xcode project")
    print("2. Ensure it's in 'Copy Bundle Resources' build phase")
    print("3. Rebuild and run the app")


if __name__ == "__main__":
    main()
