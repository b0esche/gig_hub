#!/bin/bash

# Deploy Firestore security rules to Firebase
# Make sure you have Firebase CLI installed and are logged in

echo "🔥 Deploying Firestore security rules..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Please log in to Firebase CLI:"
    echo "   firebase login"
    exit 1
fi

# Deploy only Firestore rules
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ Firestore rules deployed successfully!"
    echo ""
    echo "Your raves collection should now work with these permissions:"
    echo "- ✅ Read: All authenticated users"
    echo "- ✅ Create: Authenticated users (as organizer)"
    echo "- ✅ Update: Organizers, DJs, and collaborators"
    echo "- ✅ Delete: Only organizers"
else
    echo "❌ Failed to deploy Firestore rules"
    exit 1
fi
