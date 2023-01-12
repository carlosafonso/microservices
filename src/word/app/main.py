import os
import random
from flask import abort, Flask, request
from google.cloud import firestore


FIRESTORE_COLLECTION_NAME = 'words'
FIRESTORE_DOCUMENT_ID = 'words'
USE_DATABASE = 'USE_DATABASE' in os.environ and not os.environ['USE_DATABASE'] == ''


app = Flask(__name__)
db = firestore.Client()


@app.route('/')
def index():
    random_error_probability = 0
    if 'RANDOM_ERROR_PROBABILITY' in os.environ:
        random_error_probability = float(os.environ['RANDOM_ERROR_PROBABILITY'])
    print("Random error prob: {}".format(random_error_probability))
    if random.randint(0, 1) < random_error_probability:
        raise Exception("Random exception occured!")

    if USE_DATABASE:
        doc_ref = db.collection(FIRESTORE_COLLECTION_NAME).document(FIRESTORE_DOCUMENT_ID)
        doc = doc_ref.get()

        if not doc.exists:
            raise Exception("Document does not exist in database")

        words = doc.to_dict()['words']
    else:
        words = ['function', 'overcharge', 'consensus', 'pest', 'related', 'locate', 'earwax', 'refund', 'lead', 'stage']

    word = random.choice(words)
    print("Selected word is {}".format(word))
    return {'word': word}


@app.route('/', methods=['POST'])
def create_word():
    # Gate this endpoint behind a feature flag.
    if not USE_DATABASE:
        abort(405)

    data = request.get_json()

    if 'word' not in data:
        abort(422)

    doc_ref = db.collection(FIRESTORE_COLLECTION_NAME).document(FIRESTORE_DOCUMENT_ID)
    doc = doc_ref.get()

    words = []
    if doc.exists:
        words = doc.to_dict()['words']
        new_word = str(data['word'])
        if new_word not in words:
            words.append(new_word)

    doc_ref.set({u'words': words})
    return data
