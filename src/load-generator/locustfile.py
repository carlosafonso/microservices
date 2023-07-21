from locust import HttpUser, LoadTestShape, between, task


class CustomLoadShape(LoadTestShape):
    """This is a custom load shape that does the following:

    - Slowly ramps to 30% of MAX_USERS during the first half of the load cycle.
    - Quickly peaks to 100% of MAX_USERS during the next 10%.
    - Sustains the peak for another 10% of time.
    - Gradually ramps down to 5% of MAX_USERS throughout the rest of the cycle.

    The cycle starts again in a loop.
    """

    # The maximum number of users.
    MAX_USERS = 1000

    # The duration (in seconds) of a single load cycle.
    LOAD_SHAPE_DURATION_SECONDS = 1800

    def tick(self):
        run_time = self.get_run_time() % self.LOAD_SHAPE_DURATION_SECONDS

        # First half of load shape is a slow ramp up to 30% of MAX_USERS.
        first_half_duration_seconds = round(self.LOAD_SHAPE_DURATION_SECONDS * 0.5)
        first_half_max_users = round(self.MAX_USERS * 0.3)
        if run_time < first_half_duration_seconds:
            return (first_half_max_users, first_half_max_users / first_half_duration_seconds)

        # Next 10% of load is a spike to MAX_USERS.
        spike_duration_seconds = round(self.LOAD_SHAPE_DURATION_SECONDS * 0.1)
        if run_time < round(self.LOAD_SHAPE_DURATION_SECONDS * 0.6):
            return (self.MAX_USERS, self.MAX_USERS / spike_duration_seconds)

        # Next 10% of load is sustained MAX_USERS
        if run_time < round(self.LOAD_SHAPE_DURATION_SECONDS * 0.7):
            return (self.MAX_USERS, self.MAX_USERS)

        # Then ramp down to 5% of MAX_USERS until completion.
        ramp_down_duration_seconds = round(self.LOAD_SHAPE_DURATION_SECONDS * 0.3)
        ramp_down_min_users = round(self.MAX_USERS * 0.05)
        return (ramp_down_min_users, (self.MAX_USERS - ramp_down_min_users) / ramp_down_duration_seconds)


class FrontendServiceUser(HttpUser):
    wait_time = between(1, 5)

    @task
    def visit_frontend(self):
        self.client.get("/")
