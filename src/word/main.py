import random
from flask import Flask
app = Flask(__name__)


@app.route('/')
def index():
    words = ['function', 'overcharge', 'consensus', 'pest', 'related', 'locate', 'earwax', 'refund', 'lead', 'stage']
    word = random.choice(words)
    print("Selected word is {}".format(word))
    return {'word': word}
