import os
import random
from flask import Flask
app = Flask(__name__)


@app.route('/')
def index():
    random_error_probability = 0
    if 'RANDOM_ERROR_PROBABILITY' in os.environ:
        random_error_probability = float(os.environ['RANDOM_ERROR_PROBABILITY'])
    print("Random error prob: {}".format(random_error_probability))
    if random.randint(0, 1) < random_error_probability:
        raise Exception("Random exception occured!")

    words = ['function', 'overcharge', 'consensus', 'pest', 'related', 'locate', 'earwax', 'refund', 'lead', 'stage']
    word = random.choice(words)
    print("Selected word is {}".format(word))
    return {'word': word}
